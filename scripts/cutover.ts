/**
 * Moves ONE company's callback registrations between the Rails app and the
 * Next app, and repairs the state left behind when that goes wrong halfway.
 *
 *   pnpm cutover status    <fluid_shop>
 *   APPLY=1 pnpm cutover repoint   <fluid_shop> --url https://<app>-next-...run.app
 *   APPLY=1 pnpm cutover reconcile <fluid_shop>
 *
 * CUTOVER.md used to say "repoint it" and leave the operator to improvise.
 *
 * The important thing about this operation, established from Fluid's own
 * source rather than assumed:
 *
 *   - `Callback::Registration` sets `verification_token` in `before_create`
 *     ONLY. An update never rotates it.
 *   - `RegistrationBlueprint`'s `:shared` view exposes `verification_token`,
 *     and both `api_index` and `api_show` include that view. `api_update` does
 *     NOT.
 *   - `UpdateAction` accepts `url`.
 *
 * Together those mean a repoint is an UPDATE, not a delete-then-create. The
 * registration keeps its uuid and its token; only the url moves. That removes
 * both failure modes the delete-create shape has: there is never a moment when
 * the definition has no registration and Fluid silently stops calling, and
 * there is no create response whose loss strands a live registration whose
 * token was issued exactly once and received by nobody.
 *
 * The token is then read back from the listing and its digest stored. Fluid
 * enforces one registration per definition_name per owner, so this is still a
 * genuine switch rather than a fan-out — but it is a switch with no gap.
 *
 * Delete-then-create remains only for the case where no registration exists to
 * update.
 *
 * Writes require APPLY=1. `status` never writes.
 */

import { prisma } from "@/lib/db";
import { createFluidClient, type FluidClient } from "@/lib/fluid";
import { callbackStore } from "@/lib/callbacks";
import { activeCallbacks } from "@/lib/callbacks/registration";
import { tokenDigest } from "@fluid-app/droplet-sdk";

const APPLY = process.env.APPLY === "1";

type Registration = {
  uuid: string;
  definition_name: string;
  url: string;
  verification_token?: string;
};

function fail(message: string): never {
  console.error(`\n${message}`);
  process.exit(1);
}

async function loadCompany(handle: string) {
  const company = await prisma.company.findFirst({
    where: { OR: [{ fluidShop: handle }, { id: Number(handle) || -1 }] },
  });
  if (!company) fail(`No company matches "${handle}".`);
  if (!company.dropletInstallationUuid) {
    fail(
      `Company ${company.fluidShop} has no droplet_installation_uuid. Every ` +
        `stored token is bound to that value, so a registration made now could ` +
        `not be resolved to a tenant when its callback arrives.`,
    );
  }
  return company;
}

/**
 * Fluid's registrations for this installation, paged to the end.
 *
 * The listing is COMPANY-scoped, not droplet-scoped: it also returns
 * registrations belonging to other droplets installed for the same company. So
 * everything below matches on definition name plus url, never on definition
 * name alone.
 */
async function fluidRegistrations(client: FluidClient): Promise<Registration[]> {
  const all: Registration[] = [];
  for (let page = 1; page <= 50; page++) {
    const response = await client.listCallbacks({ page, per_page: 100 });
    const batch = (response?.callback_registrations ?? []) as Registration[];
    all.push(...batch);
    if (batch.length < 100) return all;
  }
  fail("Fluid returned more than 50 pages of registrations; refusing to guess.");
}

async function storedFor(dri: string) {
  return prisma.fluidCallbackRegistration.findMany({ where: { dri } });
}

/** Creates one registration and persists its token, or leaves nothing behind. */
async function createAndPersist(
  client: FluidClient,
  dri: string,
  definitionName: string,
  url: string,
  timeoutInSeconds: number,
): Promise<string> {
  const response = await client.createCallback({
    definition_name: definitionName,
    url,
    timeout_in_seconds: timeoutInSeconds,
    active: true,
  });
  const registration = response?.callback_registration as
    | Registration
    | undefined;

  if (!registration?.uuid) {
    throw new Error(
      `Fluid returned no uuid for ${definitionName}. A registration may or may ` +
        `not exist — run 'reconcile' before retrying.`,
    );
  }

  // A live registration exists from here. Anything that fails below has to
  // remove it, because we would be unable to verify its callbacks.
  if (!registration.verification_token) {
    await client.deleteCallback(registration.uuid).catch(() => {});
    throw new Error(
      `Fluid returned no verification_token for ${definitionName}; deleted the ` +
        `registration rather than leave one we cannot verify.`,
    );
  }

  try {
    await callbackStore.upsert({
      uuid: registration.uuid,
      dri,
      definitionName: registration.definition_name,
      tokenDigest: tokenDigest(registration.verification_token),
      url: registration.url,
    });
  } catch (error) {
    await client.deleteCallback(registration.uuid).catch(() => {});
    throw new Error(
      `Stored no digest for ${definitionName} (${
        error instanceof Error ? error.message : error
      }); deleted the registration so it cannot sit live and unverifiable.`,
    );
  }

  return registration.uuid;
}

async function status(handle: string) {
  const company = await loadCompany(handle);
  const dri = company.dropletInstallationUuid!;
  const client = createFluidClient(company.authenticationToken);

  const [live, stored, active] = await Promise.all([
    fluidRegistrations(client),
    storedFor(dri),
    activeCallbacks(),
  ]);
  const storedByUuid = new Map(stored.map((row) => [row.uuid, row]));

  console.log(`Company ${company.fluidShop} (id ${company.id}, dri ${dri})`);
  console.log(`Fluid holds ${live.length} registration(s) for this company:\n`);

  for (const registration of live) {
    const held = storedByUuid.has(registration.uuid);
    // "verifiable" is the only question that matters. A registration we hold no
    // digest for is one whose every callback we refuse behind a 200.
    console.log(
      `  ${held ? "ok    " : "NO TOKEN"} ${registration.definition_name.padEnd(24)} ${registration.url}`,
    );
  }

  const orphanRows = stored.filter(
    (row) => !live.some((registration) => registration.uuid === row.uuid),
  );
  if (orphanRows.length > 0) {
    console.log(
      `\n${orphanRows.length} stored digest(s) reference a registration Fluid no ` +
        `longer has. Harmless — nothing routes to them — but 'repoint' will ` +
        `clear them.`,
    );
  }

  const unverifiable = live.filter((r) => !storedByUuid.has(r.uuid));
  if (unverifiable.length > 0) {
    console.log(
      `\n${unverifiable.length} live registration(s) have no stored token. If any ` +
        `is at THIS app's url, its callbacks are being refused right now behind ` +
        `a 200. 'reconcile' fixes those by re-creating them.`,
    );
  }

  console.log(
    `\nThis droplet defines ${active.length} active callback(s): ` +
      active.map((c) => c.name).join(", "),
  );
}

/**
 * Reads a registration's token back from Fluid and stores its digest.
 *
 * `api_show` renders the `:shared` view, which carries `verification_token`.
 * That is what makes an in-place repoint possible at all: the token is not
 * returned by update, but it has not changed, and it can simply be read again.
 */
async function adoptToken(
  client: FluidClient,
  dri: string,
  uuid: string,
): Promise<string> {
  const response = await client.getCallback(uuid);
  const registration = response?.callback_registration as
    | Registration
    | undefined;

  if (!registration?.verification_token) {
    throw new Error(
      `Fluid returned no verification_token for ${uuid}. Without it this ` +
        `registration cannot be verified, and its callbacks would be refused ` +
        `behind a 200.`,
    );
  }

  await callbackStore.upsert({
    uuid: registration.uuid,
    dri,
    definitionName: registration.definition_name,
    tokenDigest: tokenDigest(registration.verification_token),
    url: registration.url,
  });
  return registration.url;
}

/**
 * Picks the registration that is OURS for a definition.
 *
 * The listing is company-scoped, so another droplet installed for the same
 * company can hold a registration with the same definition_name — Fluid's
 * uniqueness is per definition per OWNER. Matching on definition_name alone
 * would repoint someone else's callback at our app, which is both an outage
 * for them and traffic we cannot verify.
 *
 * So: a registration we already hold a digest for is unambiguously ours;
 * failing that, one whose url is on a host we are moving between. Anything
 * still ambiguous is reported, never guessed.
 */
function ourRegistration(
  candidates: Registration[],
  heldUuids: Set<string>,
  knownOrigins: string[],
): Registration | "ambiguous" | undefined {
  const held = candidates.filter((r) => heldUuids.has(r.uuid));
  if (held.length === 1) return held[0];
  if (held.length > 1) return "ambiguous";

  const recognised = candidates.filter((r) =>
    knownOrigins.some((origin) => r.url.startsWith(origin)),
  );
  if (recognised.length === 1) return recognised[0];
  if (recognised.length > 1) return "ambiguous";

  return undefined;
}

async function repoint(handle: string, targetUrl: string, fromUrl?: string) {
  const company = await loadCompany(handle);
  const dri = company.dropletInstallationUuid!;
  const client = createFluidClient(company.authenticationToken);

  const live = await fluidRegistrations(client);
  const stored = await storedFor(dri);
  const heldUuids = new Set(stored.map((row) => row.uuid));
  const knownOrigins = [targetUrl, ...(fromUrl ? [fromUrl] : [])];

  console.log(
    `${APPLY ? "REPOINTING" : "DRY RUN for"} ${company.fluidShop} -> ${targetUrl}\n`,
  );

  let moved = 0;

  for (const callback of await activeCallbacks()) {
    const destination = new URL(callback.url, targetUrl).toString();
    const candidates = live.filter(
      (r) => r.definition_name === callback.name,
    );
    const current = ourRegistration(candidates, heldUuids, knownOrigins);

    if (current === "ambiguous") {
      // Deliberately not resolved here. Repointing the wrong one takes down
      // another droplet's callback, and there is no signal in the listing that
      // distinguishes them once more than one is plausible.
      fail(
        `  FAIL  ${callback.name}: ${candidates.length} registrations match and ` +
          `none is unambiguously ours. Resolve by hand:\n` +
          candidates.map((r) => `    ${r.uuid}  ${r.url}`).join("\n"),
      );
    }

    if (current && current.url === destination && heldUuids.has(current.uuid)) {
      console.log(`  ok    ${callback.name}: already at ${destination}`);
      continue;
    }

    if (!APPLY) {
      console.log(
        current
          ? `  WOULD ${callback.name}: update ${current.uuid} ${current.url} -> ${destination}`
          : `  WOULD ${callback.name}: create at ${destination} (nothing registered)`,
      );
      continue;
    }

    try {
      if (current) {
        // In place. The registration keeps its uuid and its token — Fluid sets
        // the token in before_create and never rotates it — so there is no
        // moment when this definition has no registration, and no token to
        // lose. This is the whole reason the cutover is not delete-create.
        await client.updateCallback(current.uuid, { url: destination });
        const url = await adoptToken(client, dri, current.uuid);
        console.log(`  moved ${callback.name}: ${url} (${current.uuid})`);
      } else {
        const uuid = await createAndPersist(
          client,
          dri,
          callback.name,
          destination,
          callback.timeoutInSeconds,
        );
        console.log(`  created ${callback.name}: ${destination} (${uuid})`);
      }
      moved++;
    } catch (error) {
      // Stop rather than continue. After an update the registration is LIVE at
      // the new url; if adopting its token failed, callbacks are arriving and
      // being refused right now. Naming one definition is recoverable — running
      // on and doing it to five is not.
      fail(
        `  FAIL  ${callback.name}: ${error instanceof Error ? error.message : error}\n` +
          `\n  If the url moved but the token was not stored, this callback is ` +
          `being refused behind a 200 right now. Run:\n` +
          `    APPLY=1 pnpm cutover reconcile ${handle} --url ${targetUrl}\n` +
          `  or move it back with --url ${fromUrl ?? "<old url>"}.`,
      );
    }
  }

  console.log(
    APPLY
      ? `\n${moved} moved. Verify with: pnpm cutover status ${handle}`
      : `\nDry run only. Re-run with APPLY=1.`,
  );
}

/**
 * Stores digests for registrations at our url that we hold no token for.
 *
 * The recovery path, and it is a read plus a write rather than a destructive
 * re-create: the token is still readable from `api_show`, so a registration
 * whose digest we lost — a crashed cutover, a restore from a backup taken
 * before it — can simply be adopted again.
 */
async function reconcile(handle: string, targetUrl: string) {
  const company = await loadCompany(handle);
  const dri = company.dropletInstallationUuid!;
  const client = createFluidClient(company.authenticationToken);

  const live = await fluidRegistrations(client);
  const stored = await storedFor(dri);
  const heldUuids = new Set(stored.map((row) => row.uuid));
  const active = await activeCallbacks();

  // Scoped to OUR url. A registration on another host belongs to whatever
  // serves that host, and adopting its token would let this app answer for it.
  const ours = live.filter(
    (registration) =>
      registration.url.startsWith(targetUrl) &&
      active.some((c) => c.name === registration.definition_name),
  );
  const broken = ours.filter((r) => !heldUuids.has(r.uuid));

  console.log(
    `${APPLY ? "RECONCILING" : "DRY RUN for"} ${company.fluidShop}: ` +
      `${broken.length} of ${ours.length} registration(s) at ${targetUrl} have no stored token\n`,
  );

  if (broken.length === 0) {
    console.log("  Nothing to fix: every registration at this url is verifiable.");
    return;
  }

  for (const registration of broken) {
    if (!APPLY) {
      console.log(
        `  WOULD ${registration.definition_name}: adopt token for ${registration.uuid}`,
      );
      continue;
    }
    try {
      await adoptToken(client, dri, registration.uuid);
      console.log(`  fixed ${registration.definition_name}: ${registration.uuid}`);
    } catch (error) {
      fail(
        `  FAIL  ${registration.definition_name}: ${error instanceof Error ? error.message : error}`,
      );
    }
  }
}

async function main() {
  const [command, handle, ...rest] = process.argv.slice(2);
  const urlFlag = rest.indexOf("--url");
  const url = urlFlag >= 0 ? rest[urlFlag + 1] : process.env.FLUID_DROPLET_URL;
  // Optional, and only a hint: it lets a registration be recognised as ours
  // when we hold no digest for it yet — the first cutover of a company whose
  // callbacks Rails registered.
  const fromFlag = rest.indexOf("--from");
  const fromUrl = fromFlag >= 0 ? rest[fromFlag + 1]?.replace(/\/$/, "") : undefined;

  if (!command || !handle) {
    fail(
      "Usage:\n" +
        "  pnpm cutover status    <fluid_shop>\n" +
        "  APPLY=1 pnpm cutover repoint   <fluid_shop> --url https://... [--from https://rails-url]\n" +
        "  APPLY=1 pnpm cutover reconcile <fluid_shop> --url https://...",
    );
  }

  switch (command) {
    case "status":
      await status(handle);
      break;
    case "repoint":
      if (!url) fail("repoint needs --url or FLUID_DROPLET_URL.");
      await repoint(handle, url.replace(/\/$/, ""), fromUrl);
      break;
    case "reconcile":
      if (!url) fail("reconcile needs --url or FLUID_DROPLET_URL.");
      await reconcile(handle, url.replace(/\/$/, ""));
      break;
    default:
      fail(`Unknown command "${command}".`);
  }

  await prisma.$disconnect();
}

main().catch(async (error) => {
  console.error(error);
  await prisma.$disconnect();
  process.exit(1);
});
