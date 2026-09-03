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

The Rails app serves `POST /webhook` and the Next app serves
`POST /api/webhooks`, so a webhook repoint changes the path as well as the
host. The tool knows both and moves them with the callbacks — and refuses to
touch anything if it cannot first list them, because moving callbacks without
knowing where the webhooks point is how a company ends up half cut over.

`--callback-path` is required when the two apps serve the callback on different
paths, which is the normal case for a Rails→Next move. The `callbacks` table
row is operator-typed and holds the *Rails* path, so without it the repoint
would register the Next app at a route it does not serve — and for a callback
Fluid rescues into a neutral response, the symptom is not an error but a
silently missing result at checkout. It is a single override for every
definition; with more than one callback on different paths, repoint them in
separate runs.

`--from` is only a hint. It lets the tool recognise a registration as ours
before we hold any digest for it, which is the state every company is in on its
first cutover. Where more than one registration could plausibly be ours, the
tool stops and prints them rather than guessing: the listing is company-scoped,
so another droplet installed for the same company can hold a registration with
the same `definition_name`, and repointing theirs at us is an outage for them.

**If a repoint fails halfway**, read which of two things happened — they need
opposite responses, and `reconcile` only fixes one of them.

*The url moved but the token did not get stored.* The failure message names the
definition and says the callback is live and being refused behind a 200. Only
the digest is missing, so:

```bash
APPLY=1 pnpm cutover reconcile acme --url https://<app>-next-...run.app
```

*A later callback or webhook update failed outright.* Then some registrations
are at the new url and some are still at the old one — one shopper's checkout
hitting two different apps. `reconcile` will NOT fix this and will report
"Nothing to fix", because every registration it can see is either already valid
or not at the target url. Either finish the move by re-running the repoint, or
put everything back:

```bash
APPLY=1 pnpm cutover repoint acme \
  --url https://<app>-...run.app \
  --from https://<app>-next-...run.app \
  --webhook-path /webhook
```

The failure message prints the exact rollback command, including
`--webhook-path`, along with every callback and webhook it had already moved.

**3. Real companies, smallest first.** Same procedure. Stop at the first
surprise.

**4. Move the droplet-level webhooks.** `cutover repoint` moves one company's
callbacks and its per-company webhooks. It does NOT move the two droplet-level
lifecycle registrations — `droplet.installed` and `droplet.uninstalled` — which
live on the droplet record itself, not on any installation, and still point at
Rails.

Nothing surfaces this: every company can be fully cut over and working while
the next install or uninstall still goes to Rails. Delete Rails first and those
events are simply lost.

In Fluid's droplet settings, update `fluid_webhook.url` to
`https://<app>-next-...run.app/api/webhooks` and press **Update Droplet**. Then
confirm the active callback configuration points at the Next app too, so a NEW
installation registers its callbacks there rather than back onto Rails.

Do this only once every company has been repointed — it is global, not
per-tenant, and there is no partial version of it.

**There is a race here, and it needs a freeze.** The step is two global changes:
move the lifecycle webhooks, then point the active callback rows at the Next
app. A company that installs between them is handled by Next, which reads the
still-Rails callback urls out of the shared `callbacks` table and registers that
company's callbacks *on Rails* — and editing the catalogue row afterwards does
not move a registration that already exists. The whole procedure then completes
successfully while that one company is left pointing at a service you are about
to delete.

Doing the two in the other order is worse: Rails registers a callback pointing
at Next and discards the verification token, so Next refuses every one of its
calls behind a neutral 200.

So: pause installs for this droplet across the two changes, or afterwards run
`pnpm cutover status` for every company created during the window and repoint
any that came up on Rails.

**5. Retire Rails.** Min-instances to 0 first and leave it a while — that is
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
APPLY=1 pnpm cutover repoint acme \
  --url https://<app>-...run.app \
  --from https://<app>-next-...run.app \
  --webhook-path /webhook
```

`--webhook-path /webhook` is required going back. Rails serves `POST /webhook`
while the Next app serves `POST /api/webhooks`, and the tool will not guess the
direction — without it, every webhook would be moved to a Rails route that does
not exist and each delivery would 404.

Because the repoint is an update, the rollback is symmetric and has the same
no-gap property. Keep the Rails service warm until you stop needing it.
