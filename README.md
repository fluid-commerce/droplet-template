## README

> ### ⚠️ This repository currently contains two apps
>
> A **Next.js** app is being migrated in alongside the existing **Rails 8** app.
> Both run against the same PostgreSQL database. The Rails app is still the one
> deployed; the Next app is not live yet, and removing Rails is a deliberate
> follow-up PR, not part of the migration PR.
>
> See [Next.js app](#nextjs-app) below, and
> [`vendor/droplet-sdk/README.md`](vendor/droplet-sdk/README.md) for the one
> known blocker.

Droplets are integrations between third-party services and Fluid. This is a repository intended to be used as an example for creating Droplets.

Documentation can be found in the [project's GitHub page](https://fluid-commerce.github.io/droplet-template/)

## Next.js app

The Next.js port of this droplet. Same database, same Fluid integration points,
plus signature verification via `@fluid-studios/droplet-sdk`.

### Layout

| Path | What |
|---|---|
| `src/` | The Next app — **and its project directory**. `next.config.ts`, `tsconfig.json` and `next-env.d.ts` live here, not at the repo root. |
| `src/app/` | App Router: admin UI, `/api/webhooks`, `/api/callbacks/*`, `/api/health` |
| `src/lib/` | Fluid client, settings, callbacks, handlers, events, permissions |
| `prisma/schema.prisma` | The **existing Rails tables**, mapped with `@@map`/`@map` |
| `scripts/` | `backfill-callback-tokens.ts`, `create-admin.ts`, `create-default-settings.ts` |
| `vendor/droplet-sdk/` | Temporary vendored copy of the SDK — see below |
| `Dockerfile.next` | Production image (the Rails `Dockerfile` is untouched) |
| `.github/workflows/ci-next.yml` | Lint / typecheck / test / build / docker |

**Why `next.config.ts` is inside `src/`.** Next resolves its app directory with
`findDir(root, "app")`, which prefers `<root>/app` over `<root>/src/app` and
cannot be overridden. This repo still contains Rails' `app/`, so building from
the repo root makes Next scan Rails' directory and emit an empty app. Next is
therefore pointed at `src` as its project directory — `next build src`. When
Rails is removed, those three config files move up one level and the commands
drop the `src` argument. No source file moves and no import path changes.

### Commands

```bash
pnpm install
pnpm db:generate          # prisma generate
pnpm dev                  # next dev src
pnpm build                # prisma generate && next build src
pnpm test                 # vitest
pnpm lint
pnpm typecheck

pnpm setup:create-admin   # ADMIN_EMAIL / ADMIN_PASSWORD
pnpm settings:defaults    # create the default `settings` rows
pnpm backfill:callbacks   # copy callback verification tokens out of Fluid
```

The Rails frontend's Vite build is still here under `pnpm build:vite` and
`pnpm test:jest`. The repo's JS toolchain moved from yarn to pnpm when the Next
app took over the root `package.json`; `ci.yml` and `Dockerfile` were updated to
match, and nothing under `app/`, `config/` or `Gemfile` changed.

### The SDK is vendored, temporarily

`@fluid-studios/droplet-sdk` is **not published**, and cannot be under that
name: GitHub Packages requires the npm scope to match the repository owner, the
owner is `fluid-commerce`, and there is no `fluid-studios` GitHub org — so
publishing returns `403 Permission not_found: owner not found`. Publishing it
means renaming the package to `@fluid-commerce/droplet-sdk`, which is deferred
because reviewed droplet PRs already depend on the current name.

So the SDK source is vendored at `vendor/droplet-sdk` and depended on as
`"@fluid-studios/droplet-sdk": "link:./vendor/droplet-sdk"`. `pnpm install`,
`pnpm build` and `pnpm test` work on a clean clone with no registry
authentication. **Anyone forking this template needs to change one line** once
the package is published — the swap is documented in
[`vendor/droplet-sdk/README.md`](vendor/droplet-sdk/README.md). Import
specifiers stay `@fluid-studios/droplet-sdk` so the rename is a
find-and-replace.

### Authentication

Auth.js (NextAuth v5) with a credentials provider, verifying bcrypt against the
existing `users.encrypted_password`. Devise's `config.pepper` is unset in this
app, so the digest is plain bcrypt at cost 12 and **existing user rows keep
working with no password reset**. New digests are written as `$2a$` by
`bcryptjs@2`, which bcrypt-ruby also reads, so both apps can authenticate the
same rows while they run side by side. `src/lib/auth/password.test.ts` pins both
directions against real bcrypt-ruby output.

### Callbacks: read this before enabling one

Fluid calls callbacks synchronously during a live checkout and blocks the
storefront request on the response. So `/api/callbacks/*` routes answer **HTTP
200 for every outcome, auth failures included** — a 401 is a broken cart. The
status therefore tells you nothing. Alert on the
`[fluid-callback:…] rejected` log line instead.

Rollout order for an installation that predates verification, per the SDK
README:

1. Deploy the schema (`fluid_callback_registrations`) and the registration code.
2. Run `pnpm backfill:callbacks` **by hand** against production, and confirm it
   exits zero. It stages the whole replacement set, checks every enabled
   callback has a token, and only then swaps in one transaction — an
   installation's digests are never deleted before their replacements are held.
3. Only then let the wrapped routes take traffic.

Deploying step 3 before step 2 rejects every genuine callback, silently.

### Cutting over from Rails

The two apps expose the webhook endpoint at different paths — Rails at `POST
/webhook`, Next at `POST /api/webhooks`. Fluid calls whatever URL is stored in
the `fluid_webhook` settings row, so the cutover is: point that row's `url` at
the Next deployment, press **Update Droplet** on the dashboard (which pushes the
change to Fluid via `PUT /api/company/webhooks/:id`), and confirm an install
arrives. Nothing in the database changes.

### Deliberately not ported

- **Devise's `:registerable`, `:recoverable`, `:rememberable` flows.** Public
  sign-up on an internal admin console was not worth reproducing, and password
  reset needs a mailer this app does not have (nor did Rails — its mailer was
  the unconfigured default). The `reset_password_token` /
  `reset_password_sent_at` columns are preserved so it can be added later
  without a migration.
- **Solid Queue.** Webhook handlers run inline in the route rather than in a
  background job — see the note in `src/lib/events/event-handler.ts`.
- **The `events`, `webhooks` and `integration_settings` tables' behaviour.**
  All three are model-only in the Rails app, with no call sites anywhere. They
  are mapped in the Prisma schema so the database is fully described, but no
  behaviour was invented for them.
- **`/api/drop_zones`.** The Rails template never registered a dropzone, so
  nothing was ported. The endpoints are real and a fork can add them.

## Rails app

## Production environment

### Google cloud infrastructure

- Google Cloud Run (Web)
- Google Cloud Storage (Terraform)
- Google Cloud SQL (postgreSQL)
- Google Cloud Build (CI/CD)
- Google Cloud Compute Engine (jobs console)
- Artifact Registry (Docker)

web: Google Cloud Run name `fluid-droplet-NAME`

jobs console: Google Cloud Compute Engine name `fluid-droplet-NAME-jobs-console`

### Deploy to google cloud

Run github action to deploy to google cloud `deploy production`
or run the following command to deploy to google cloud  

`gcloud beta builds submit --config cloudbuild-production.yml --region=us-west3 --substitutions=COMMIT_SHA=$(git rev-parse --short HEAD),_TIMESTAMP=$(date +%Y%m%d%H%M%S) --project=fluid-417204 .`

### Add environment variables to google cloud

Add environment variables to google cloud `add-update-env-gcloud.sh` and run the following command to add environment variables to google cloud
`sh add-update-env-gcloud.sh`

### Sentry Configuration

This project includes Sentry integration for error monitoring and performance tracking. To enable Sentry:

1. **Create a Sentry project:**
   - Go to [Sentry.io](https://sentry.io) and create a new project
   - Select "Ruby" as the platform
   - Copy the DSN from your project settings

2. **Set the environment variable:**
   - Add `SENTRY_DSN` to your environment variables with the DSN from your Sentry project
   - For local development, add it to your `.env` file:
     ```bash
     SENTRY_DSN=https://your-dsn@sentry.io/project-id
     ```
   - For production, add it to your Google Cloud environment variables

3. **Sentry features enabled:**
   - Automatic error tracking and reporting
   - Performance monitoring
   - Request headers and IP data collection (for debugging)
   - Active Support and HTTP logger breadcrumbs

The Sentry integration will only be active when the `SENTRY_DSN` environment variable is present and configured.

### Technology Stack

![PostgreSQL 17](https://img.shields.io/badge/PostgreSQL-17-336791?logo=postgresql&logoColor=white)
![Ruby](https://img.shields.io/badge/Ruby-3.4.2-CC342D?logo=ruby&logoColor=white)
![Rails](https://img.shields.io/badge/Rails-8.0.2-CC0000?logo=ruby-on-rails&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-23.8.0-339933?logo=node.js&logoColor=white)
![Yarn](https://img.shields.io/badge/Yarn-4.7.0-2C8EBB?logo=yarn&logoColor=white)
![Font Awesome](https://img.shields.io/badge/Font_Awesome-6.7.2-528DD7?logo=fontawesome&logoColor=white)
![Tailwind CSS 4.0](https://img.shields.io/badge/Tailwind_CSS-4.0-38B2AC?logo=tailwindcss&logoColor=white)
<br>

## Local environment

### Running locally

Install dependencies with `bundle install` and `yarn install`
and install foreman with `gem install foreman`  
Just the rails server (port 3000)<br>
`foreman start -f Procfile.dev`

Running everything (port 3200)<br>
`bin/dev`

### Running locally with docker

This approach allows you to use your local PostgreSQL instance with Docker.

**Prerequisites:**
- Docker installed
- PostgreSQL running locally
- Database `droplet_template_development` created

**Step-by-step setup:**

1. **Copy environment file:**
   ```bash
   cp .env.local.example .env
   ```

2. **Edit `.env` file with your database credentials:**
   ```bash
   # Required
   SECRET_KEY_BASE=your_secret_key_here

   # Database connection (use your local PostgreSQL)
   DATABASE_URL=postgresql://username:password@host.docker.internal:5432/droplet_template_development

   # Environment
   RAILS_ENV=development
   ```

3. **Build the Docker image:**
   ```bash
   docker build -t droplet-template .
   ```

4. **Run database migrations (if needed):**
   ```bash
   # If you haven't run migrations yet, run them first
   docker run --env-file .env -e RAILS_ENV=development droplet-template bin/rails db:migrate
   ```

5. **Run the container:**
   ```bash
   docker run -p 3200:80 --env-file .env -e RAILS_ENV=development droplet-template
   ```

6. **Access the application:**
   Open your browser and go to: `http://localhost:3200`

**Notes:**
- Use `host.docker.internal` instead of `localhost` in DATABASE_URL for Docker to access your local PostgreSQL
- The application will run on port 3200 (mapped from container port 80)
- Make sure your PostgreSQL is running and accessible before starting the container

### Running with Docker for development (with Vite and hot reload)

For a full development experience with Vite, TypeScript compilation, and hot reload:

1. **Copy environment file:**
   ```bash
   cp .env.local.example .env
   ```

2. **Edit `.env` file with your database credentials:**
   ```bash
   # Required
   SECRET_KEY_BASE=your_secret_key_here

   # Database connection (use your local PostgreSQL)
   DATABASE_URL=postgresql://username:password@host.docker.internal:5432/droplet_template_development

   # Environment
   RAILS_ENV=development
   ```

3. **Build the development Docker image:**
   ```bash
   docker build -f Dockerfile.dev -t droplet-template-dev .
   ```

4. **Run the development container:**
   ```bash
   docker run -p 3200:3000 -p 3036:3036 --env-file .env -e RAILS_ENV=development droplet-template-dev
   ```

5. **Access the application:**
   - **Rails**: http://localhost:3200
   - **Vite**: http://localhost:3036

**Development features:**
- Hot reload for frontend changes
- TypeScript compilation in watch mode
- Vite dev server for fast frontend development
- Full Rails development environment

### License

MIT License

Copyright (c) 2025 Fluid Commerce

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
