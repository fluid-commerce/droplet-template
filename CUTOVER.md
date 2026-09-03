# Cutting a droplet over from Rails to Next

Both apps read the same database — the Next app maps onto the Rails tables with
`@@map`, and there is no data migration. What decides which app serves a company
is not a hostname or a load balancer: **Fluid calls whatever url is recorded in
that installation's callback and webhook registrations.** The registration table
is the routing table, and it is keyed per company.

That is what makes this safe to do one tenant at a time.

## Why not a percentage split

Two reasons, both concrete.

A split sends one shopper's `cart_item_added` to Rails and their
`update_cart_tax` to Next. Different pricing or tax inside a single checkout.

And webhooks are at-least-once with per-app idempotency. Two apps behind one url
both act on the same event: two order syncs, two payment records. Nothing
deduplicates across the app boundary because neither app knows the other exists.

Per-company cutover has a blast radius of one tenant, an instant rollback, and
no double-processing.

## The sequence

**0. Deploy.** Run `deploy next`. It builds `Dockerfile.next` and deploys the
`<app>-next` Cloud Run service. Nothing points at it, so this changes nothing —
that is the property worth having.

**1. Smoke.** `scripts/smoke-next.sh <url>`. Read its header first: the callback
route fails open by design, so an unauthenticated probe cannot tell verification
working from verification broken. The webhook assertions are the ones with
teeth.

**2. One internal installation.** Repoint it, watch it, put it back if needed.

```bash
pnpm cutover status    acme                                  # read-only
pnpm cutover repoint   acme --url https://<app>-next-...run.app --from https://<app>-...run.app
APPLY=1 pnpm cutover repoint acme --url https://<app>-next-...run.app --from https://<app>-...run.app
pnpm cutover status    acme                                  # confirm
```

The repoint is an **update in place**, not a delete-then-create, and that is
load-bearing. Fluid sets `verification_token` in `before_create` and never
rotates it, `UpdateAction` accepts `url`, and `api_show` renders the `:shared`
view which still carries the token. So the registration keeps its uuid and its
token while only the url moves, and the tool reads the token back afterwards to
store its digest.

That removes both ways the obvious shape goes wrong. There is no window where
the definition has no registration and Fluid quietly stops calling — which for
a tax callback would be a cart priced without tax. And there is no create
response whose loss would strand a live registration whose token was issued
exactly once, to nobody.

`--from` is only a hint. It lets the tool recognise a registration as ours
before we hold any digest for it, which is the state every company is in on its
first cutover. Where more than one registration could plausibly be ours, the
tool stops and prints them rather than guessing: the listing is company-scoped,
so another droplet installed for the same company can hold a registration with
the same `definition_name`, and repointing theirs at us is an outage for them.

**If a repoint fails halfway**, the url may have moved while the digest did not
— the callback is then live and being refused behind a 200. Fix it with:

```bash
APPLY=1 pnpm cutover reconcile acme --url https://<app>-next-...run.app
```

`reconcile` reads the token back for anything at our url we hold no digest for.
It is a read plus a write, not a destructive re-create.

**3. Real companies, smallest first.** Same procedure. Stop at the first
surprise.

**4. Retire Rails.** Min-instances to 0 first and leave it a while — that is
reversible in seconds. Delete only once nothing has needed it.

## Rules while both apps are live

**Rails owns the schema.** Two migration tools against one database produces a
schema neither app agrees with. Freeze Rails migrations during a cutover window,
and keep Prisma read-shaped: `db pull`, never `db push`. There is no `db:push` guard in this
repo — `pnpm db:push` will happily reshape the Rails schema, so treat that
command as unavailable during a cutover window rather than as guarded.

**Watch for encrypted columns.** Where Rails uses `encrypts`, Prisma reads the
raw column and gets the base64 envelope. The droplet then reads every company as
*unconfigured* — no error, no exception, just a droplet that believes nobody has
set it up. This template does not encrypt anything; shipstation, avalara and
sovos do, and each needs that verified against real stored config before it goes
anywhere near a cutover.

**A rollback is the same command with the urls swapped.**

```bash
APPLY=1 pnpm cutover repoint acme --url https://<app>-...run.app --from https://<app>-next-...run.app
```

Because the repoint is an update, the rollback is symmetric and has the same
no-gap property. Keep the Rails service warm until you stop needing it.
