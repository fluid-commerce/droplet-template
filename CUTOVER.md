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

**2. One internal installation.** Repoint it, watch it, and be ready to put it
back. Fluid enforces one registration per `definition_name` per owner, so this
is a genuine switch and not a fan-out — there is no mirror mode to hide behind.

Repointing is delete-then-create, not update, because **an update does not
return a `verification_token` and a create does**. The new registration's token
is stored by the Next app as it creates it, which is also how that app ends up
able to verify at all.

There is a gap of a second or two where the definition has no registration and
Fluid simply does not call. For most callbacks that is a no-op; for a tax
callback it means a cart priced without tax. Do it off-peak.

**3. Real companies, smallest first.** Same procedure. Stop at the first
surprise.

**4. Retire Rails.** Min-instances to 0 first and leave it a while — that is
reversible in seconds. Delete only once nothing has needed it.

## Rules while both apps are live

**Rails owns the schema.** Two migration tools against one database produces a
schema neither app agrees with. Freeze Rails migrations during a cutover window,
and keep Prisma read-shaped: `db pull`, never `db push`. `guard-db-push.sh`
already blocks that against production.

**Watch for encrypted columns.** Where Rails uses `encrypts`, Prisma reads the
raw column and gets the base64 envelope. The droplet then reads every company as
*unconfigured* — no error, no exception, just a droplet that believes nobody has
set it up. This template does not encrypt anything; shipstation, avalara and
sovos do, and each needs that verified against real stored config before it goes
anywhere near a cutover.

**A rollback is the same operation backwards.** Delete the Next registrations,
re-create them against the Rails url. Keep the Rails service warm until you stop
needing that.
