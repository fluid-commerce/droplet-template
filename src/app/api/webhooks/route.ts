/**
 * Webhook endpoint.
 *
 * Port of app/controllers/webhooks_controller.rb, wrapped in the SDK's
 * `withFluidWebhook`.
 *
 * Webhooks are not the checkout path, so this route refuses loudly: an
 * unverified request gets a 401 and nothing runs. That is the opposite of the
 * callback routes, and it is deliberate — a rejected webhook is a retry, while
 * a rejected callback is a broken cart.
 *
 * What the wrapper replaces, and why it is an improvement on the Ruby:
 *
 *  - The Rails controller authenticated `droplet.installed` / `droplet.uninstalled`
 *    by comparing `params[:company][:droplet_uuid]` against the configured
 *    droplet uuid. That is a value the caller supplies, so anyone who knew the
 *    droplet's uuid — which Fluid publishes in the marketplace — could forge an
 *    install and hand this droplet a `companies` row with credentials of their
 *    choosing. Here the same events are verified by HMAC against the shared
 *    bootstrap secret, and the uuid check remains as a routing guard inside the
 *    handler rather than as the authentication.
 *  - Every other event was authenticated by a plaintext `AUTH_TOKEN` header
 *    compared with `include?` — not timing-safe, and satisfied by the SHARED
 *    webhook token, so any installed company's token authenticated a webhook
 *    about any other company. Here a non-bootstrap event must verify against
 *    that company's own `webhook_verification_token`.
 */

import { withFluidWebhook, INSTALL_EVENT } from "@fluid-app/droplet-sdk/next";
import { NextResponse } from "next/server";

import { prisma } from "@/lib/db";
import { routeEvent, hasHandler } from "@/lib/events";
import { initializeHandlers } from "@/lib/handlers";

initializeHandlers();

/**
 * Events allowed to authenticate with the shared bootstrap secret.
 *
 * `droplet.installed` has to be here: it is the event that delivers the
 * company's own token, so no per-company secret exists yet.
 *
 * `droplet.uninstalled` is here too, because Fluid signs it with the same
 * droplet-level webhook this app registers (WebhookManager creates both with
 * `auth_token: fluid_webhook.auth_token`), not with the company's token.
 */
const BOOTSTRAP_EVENTS = [INSTALL_EVENT, "droplet.uninstalled"];

/**
 * The object a handler should run on.
 *
 * Fluid delivers lifecycle events in two shapes and the SDK recognises both:
 *
 *   root form      {resource, event, company, ...}
 *   envelope form  {name, payload: {company, ...}}
 *
 * Forwarding the outer object unchanged broke the envelope form — the handler's
 * schema needs `company` at the top level, so it threw and the route answered
 * 500, which Fluid retries indefinitely.
 *
 * But unwrapping whenever an object-valued `payload` exists breaks the OTHER
 * form: a root-form delivery that also carries a domain field named `payload`
 * would have its real body discarded and `payload`'s contents handed to the
 * handler instead. So the shape is DECIDED, not sniffed — root fields win,
 * because their presence is what the SDK used to recognise the event.
 */
export function payloadForHandler(body: unknown): unknown {
  if (typeof body !== "object" || body === null || Array.isArray(body)) {
    return body;
  }
  const outer = body as Record<string, unknown>;

  // Root form: `resource` + `event` at the top level. The body IS the payload,
  // whatever else it happens to contain.
  if (typeof outer.resource === "string" && typeof outer.event === "string") {
    return outer;
  }

  const inner = outer.payload;
  const innerIsObject =
    typeof inner === "object" && inner !== null && !Array.isArray(inner);

  // Envelope form: a `name` discriminator, or a nested resource/event pair.
  if (innerIsObject) {
    const nested = inner as Record<string, unknown>;
    if (
      typeof outer.name === "string" ||
      (typeof nested.resource === "string" && typeof nested.event === "string")
    ) {
      return inner;
    }
  }

  return body;
}

export const POST = withFluidWebhook(
  {
    name: "droplet",
    bootstrapSecret: process.env.FLUID_WEBHOOK_AUTH_TOKEN,
    bootstrapEvents: BOOTSTRAP_EVENTS,

    /**
     * Finds the candidate secret for a webhook, from untrusted routing hints.
     *
     * Unlike a callback, a webhook's secret is per-company, so the tenant has
     * to be guessed before verification and only trusted afterwards. Returning
     * null means no candidate — which for a bootstrap event is fine, the shared
     * secret is tried next, and for anything else is an auth failure.
     */
    async resolve({ dri, fluidShop, companyId }) {
      const company = dri
        ? await prisma.company.findFirst({
            where: { dropletInstallationUuid: dri },
          })
        : companyId !== undefined
          ? await prisma.company.findFirst({
              where: { fluidCompanyId: BigInt(companyId) },
            })
          : fluidShop
            ? await prisma.company.findFirst({ where: { fluidShop } })
            : null;

      if (!company?.webhookVerificationToken) return null;

      return {
        secret: company.webhookVerificationToken,
        principal: company,
      };
    },
  },

  async ({ event, payload }) => {
    console.log(`[Webhook] Received: ${event}`);

    // Rails answered 204 when nothing was registered for the event, and 202
    // when a job was enqueued. Both are kept; the difference is that the work
    // has actually finished by the time 202 is returned. See the note in
    // src/lib/events/event-handler.ts on why this runs inline.
    if (!hasHandler(event)) {
      return new NextResponse(null, { status: 204 });
    }

    try {
      // Handlers are given the INNER payload, not the outer envelope.
      //
      // Fluid sends lifecycle events in two shapes — root-style
      // `{resource, event, company}` and enveloped
      // `{name, payload: {company}}` — and the SDK recognises both when it
      // decides what `event` is. But forwarding the outer object unchanged
      // means an enveloped delivery reaches a handler whose schema requires
      // `company` at the top level: it throws, the route answers 500, and
      // Fluid retries the same shape forever.
      const handled = await routeEvent(event, payloadForHandler(payload));
      return new NextResponse(null, { status: handled ? 202 : 204 });
    } catch (error) {
      // The payload is never logged here: it carries authentication_token and
      // webhook_verification_token on an install.
      console.error(
        `[Webhook] Handler failed for ${event}:`,
        error instanceof Error ? error.message : error,
      );
      // A 5xx is a retry signal to Fluid, which is what a transient database or
      // Fluid API failure deserves.
      return NextResponse.json(
        { error: "internal error" },
        { status: 500 },
      );
    }
  },
);

export function GET() {
  return NextResponse.json({ status: "ok", service: "droplet-template-webhooks" });
}
