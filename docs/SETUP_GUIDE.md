# Complete Setup Guide (Beginner Friendly)

This guide covers deploying Chatwoot with all Enterprise features unlocked — both locally and on a server with Coolify.

Our changes are designed to **never conflict with upstream updates**. You can always pull new code from the official Chatwoot repo safely.

---

## Table of Contents

1. [What We Changed (and Why It's Safe)](#what-we-changed-and-why-its-safe)
2. [Local Development Setup (macOS)](#local-development-setup-macos)
3. [Production Deployment with Coolify](#production-deployment-with-coolify)
4. [Production Deployment without Coolify](#production-deployment-without-coolify)
5. [Enterprise Seed Commands](#enterprise-seed-commands)
6. [After Deployment Checklist](#after-deployment-checklist)
7. [Updating to Latest Version](#updating-to-latest-version)
8. [Troubleshooting](#troubleshooting)

---

## What We Changed (and Why It's Safe)

### Files we ADDED (no conflict possible — these don't exist upstream):

| File | Purpose |
|------|---------|
| `custom/app/jobs/custom/internal/check_new_versions_job.rb` | Prevents daily job from resetting your plan to "community" |
| `lib/tasks/enterprise_setup.rake` | One-command enterprise setup |
| `docs/*` | Documentation |
| `docker-compose.dev.yml` | Local dev Docker services |

### Files we MODIFIED (minimal changes, easy to re-apply after merge):

| File | Change | Why |
|------|--------|-----|
| `config/application.rb` | Added 1 line: `custom/app/**` to eager_load_paths | Rails needs to know about the `custom/` folder |
| `config/initializers/01_inject_enterprise_edition_module.rb` | Fixed `false` vs `nil` bug in `const_get_maybe_false` | Upstream bug that crashes when `custom/` folder exists |

Both are 1-line fixes. If upstream ever fixes these, the merge conflict is trivial — just accept their version.

### Files we DID NOT touch:

- ❌ No changes to `enterprise/` directory
- ❌ No changes to `app/` directory
- ❌ No changes to frontend code
- ❌ No changes to database migrations

---

## Local Development Setup (macOS)

### Prerequisites

- macOS with Homebrew installed
- Docker Desktop installed and running
- Git

### Step 1: Clone your fork

```bash
git clone https://github.com/YOUR_USERNAME/chatwoot.git
cd chatwoot
git checkout develop
```

### Step 2: Install Ruby

```bash
brew install rbenv ruby-build
eval "$(rbenv init -)"
rbenv install $(cat .ruby-version)
# This installs Ruby 3.4.4 (takes ~5 minutes)
```

Add to your `~/.zshrc` so rbenv loads automatically:
```bash
echo 'eval "$(rbenv init -)"' >> ~/.zshrc
source ~/.zshrc
```

### Step 3: Install Node.js

```bash
# If using nvm:
nvm install $(cat .nvmrc)
nvm use $(cat .nvmrc)

# Install pnpm
npm install -g pnpm
```

### Step 4: Install libpq (needed for PostgreSQL gem)

```bash
brew install libpq
bundle config build.pg --with-pg-config=/opt/homebrew/opt/libpq/bin/pg_config
```

### Step 5: Start PostgreSQL + Redis via Docker

```bash
docker compose -f docker-compose.dev.yml up -d
```

This starts:
- PostgreSQL 16 with pgvector (port 5432)
- Redis 7 (port 6379)

### Step 6: Configure .env

```bash
cp .env.example .env
```

Edit `.env` and set:
```
POSTGRES_HOST=localhost
POSTGRES_USERNAME=chatwoot
POSTGRES_PASSWORD=chatwoot
REDIS_URL=redis://localhost:6379
SECRET_KEY_BASE=replace_with_any_long_random_string_here
FRONTEND_URL=http://localhost:3000
RAILS_ENV=development
```

### Step 7: Install dependencies

```bash
bundle install
pnpm install
```

### Step 8: Setup database

```bash
bundle exec rails db:create
bundle exec rails db:schema:load
bundle exec rails db:seed
```

> **Why `db:schema:load` instead of `db:migrate`?**
> Fresh installs should use `schema:load` — it creates all tables at once from the final schema.
> `db:migrate` runs each migration file one by one and can hit errors with old migrations.
> Use `db:migrate` only when updating an existing database.

### Step 9: Enterprise setup

```bash
bundle exec rails chatwoot:enterprise_setup
```

This enables all premium features. Run once after first setup.

### Step 10: Start the app

```bash
brew install overmind  # process manager (one-time)
pnpm dev
```

Open http://localhost:3000

**Default login:**
- Email: `john@acme.inc`
- Password: `Password1!`
- Super Admin panel: http://localhost:3000/super_admin

---

## Production Deployment with Coolify

### Prerequisites

- A server (recommend: 4+ CPU, 8+ GB RAM — Hetzner CPX31 ~$17/mo)
- Coolify installed on the server
- Your fork on GitHub (public or private)
- A domain name pointing to your server

### Step 1: Create Docker Compose service in Coolify

1. Coolify Dashboard → Add Resource → Docker Compose
2. Source: GitHub → select your repo
3. Branch: `develop`
4. Docker Compose file — use this:

```yaml
services:
  base: &base
    build:
      context: .
      dockerfile: docker/Dockerfile
    volumes:
      - chatwoot_storage:/app/storage

  rails:
    <<: *base
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_started
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - RAILS_ENV=production
      - INSTALLATION_ENV=docker
    entrypoint: docker/entrypoints/rails.sh
    command: ['bundle', 'exec', 'rails', 's', '-p', '3000', '-b', '0.0.0.0']
    restart: always

  sidekiq:
    <<: *base
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_started
    environment:
      - NODE_ENV=production
      - RAILS_ENV=production
      - INSTALLATION_ENV=docker
    command: ['bundle', 'exec', 'sidekiq', '-C', 'config/sidekiq.yml']
    restart: always

  postgres:
    image: pgvector/pgvector:pg16
    restart: always
    volumes:
      - chatwoot_postgres:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=chatwoot_production
      - POSTGRES_USER=chatwoot
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U chatwoot"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    restart: always
    command: ["sh", "-c", "redis-server --requirepass ${REDIS_PASSWORD}"]
    volumes:
      - chatwoot_redis:/data

volumes:
  chatwoot_storage:
  chatwoot_postgres:
  chatwoot_redis:
```

### Step 2: Set environment variables in Coolify

Add these as shared environment variables:

```bash
# Required
SECRET_KEY_BASE=generate_a_64_char_hex_string
FRONTEND_URL=https://chat.yourdomain.com
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_USERNAME=chatwoot
POSTGRES_PASSWORD=a_strong_password_here
POSTGRES_DATABASE=chatwoot_production
REDIS_URL=redis://:your_redis_password@redis:6379
REDIS_PASSWORD=your_redis_password
RAILS_ENV=production
NODE_ENV=production
RAILS_LOG_TO_STDOUT=true
ACTIVE_STORAGE_SERVICE=local
ENABLE_ACCOUNT_SIGNUP=false

# Email (needed for invitations)
SMTP_ADDRESS=smtp.yourdomain.com
SMTP_PORT=587
SMTP_USERNAME=noreply@yourdomain.com
SMTP_PASSWORD=your_smtp_password
MAILER_SENDER_EMAIL=Chat <noreply@yourdomain.com>

# Push notifications (use official relay)
ENABLE_PUSH_RELAY_SERVER=true


# Prevents sending usage metrics to Chatwoot hub server
# Used alongside custom/ overlay for full enterprise protection
DISABLE_TELEMETRY=true
```

Generate `SECRET_KEY_BASE` with:
```bash
openssl rand -hex 64
```

### Step 3: Set domain in Coolify

- Map domain `chat.yourdomain.com` to the `rails` service, port 3000
- Enable HTTPS (Coolify handles Let's Encrypt automatically)

### Step 4: Deploy

Click Deploy. First build takes ~10-15 minutes.

### Step 5: Database setup (first time only)

After deploy succeeds, open terminal in Coolify for the `rails` service:

```bash
bundle exec rails db:prepare
bundle exec rails db:seed
bundle exec rails chatwoot:enterprise_setup
```

### Step 6: Create your admin account

Visit `https://chat.yourdomain.com` and sign up (if `ENABLE_ACCOUNT_SIGNUP=true`) or create via console:

```bash
bundle exec rails console
```

```ruby
user = User.new(
  name: 'Admin',
  email: 'admin@yourdomain.com',
  password: 'YourStrongPassword1!',
  type: 'SuperAdmin'
)
user.skip_confirmation!
user.save!

account = Account.create!(name: 'My Company')
AccountUser.create!(account: account, user: user, role: :administrator)
```

---

## Production Deployment without Coolify

### Prerequisites

- Ubuntu 22.04/24.04 server (4+ CPU, 8+ GB RAM)
- Domain pointing to server
- SSH access

### Step 1: Install system dependencies

```bash
sudo apt update
sudo apt install -y git curl build-essential libssl-dev libreadline-dev \
  zlib1g-dev libyaml-dev libffi-dev libpq-dev nginx certbot \
  python3-certbot-nginx

# Install rbenv + Ruby
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'eval "$(~/.rbenv/bin/rbenv init -)"' >> ~/.bashrc
source ~/.bashrc
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
rbenv install 3.4.4
rbenv global 3.4.4

# Install Node.js 24
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt install -y nodejs
npm install -g pnpm

# Install PostgreSQL 16 + pgvector
sudo apt install -y postgresql-16 postgresql-16-pgvector

# Install Redis
sudo apt install -y redis-server
```

### Step 2: Setup PostgreSQL

```bash
sudo -u postgres createuser chatwoot --superuser
sudo -u postgres psql -c "ALTER USER chatwoot WITH PASSWORD 'your_password';"
sudo -u postgres createdb chatwoot_production -O chatwoot
```

### Step 3: Clone and configure

```bash
cd /opt
sudo git clone https://github.com/YOUR_USERNAME/chatwoot.git
sudo chown -R $USER:$USER /opt/chatwoot
cd /opt/chatwoot
git checkout develop

cp .env.example .env
# Edit .env with your production values (see Coolify env vars above)
```

### Step 4: Install and build

```bash
bundle install
pnpm install
bundle exec rails assets:precompile
```

### Step 5: Database setup

```bash
RAILS_ENV=production bundle exec rails db:prepare
RAILS_ENV=production bundle exec rails db:seed
RAILS_ENV=production bundle exec rails chatwoot:enterprise_setup
```

### Step 6: Setup systemd services

Create `/etc/systemd/system/chatwoot-web.service`:
```ini
[Unit]
Description=Chatwoot Web
After=network.target

[Service]
User=deploy
WorkingDirectory=/opt/chatwoot
Environment=RAILS_ENV=production
ExecStart=/bin/bash -lc 'bundle exec puma -C config/puma.rb'
Restart=always

[Install]
WantedBy=multi-user.target
```

Create `/etc/systemd/system/chatwoot-worker.service`:
```ini
[Unit]
Description=Chatwoot Sidekiq
After=network.target

[Service]
User=deploy
WorkingDirectory=/opt/chatwoot
Environment=RAILS_ENV=production
ExecStart=/bin/bash -lc 'bundle exec sidekiq -C config/sidekiq.yml'
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable chatwoot-web chatwoot-worker
sudo systemctl start chatwoot-web chatwoot-worker
```

### Step 7: Nginx + SSL

```nginx
# /etc/nginx/sites-available/chatwoot
server {
    listen 80;
    server_name chat.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name chat.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/chat.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/chat.yourdomain.com/privkey.pem;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/chatwoot /etc/nginx/sites-enabled/
sudo certbot --nginx -d chat.yourdomain.com
sudo systemctl reload nginx
```

---

## Enterprise Seed Commands

This is what `bundle exec rails chatwoot:enterprise_setup` does internally:

```ruby
# Sets plan to enterprise (removes plan restrictions)
InstallationConfig: INSTALLATION_PRICING_PLAN = 'enterprise'

# Sets deployment type (prevents cloud-only behaviors)
InstallationConfig: DEPLOYMENT_ENV = 'self-hosted'

# Sets user limit to 100k (removes "add more licenses" banner)
InstallationConfig: INSTALLATION_PRICING_PLAN_QUANTITY = 100000

# Enables all premium features on every account
Account features: sla, audit_logs, custom_roles, captain_integration, etc.

# Sets per-account agent limit to 100k (removes seat limit warnings)
Account custom_attributes: subscribed_quantity = 100000

# Sets defaults so NEW accounts also get all features
InstallationConfig: ACCOUNT_LEVEL_FEATURE_DEFAULTS = [all features enabled]
```

**When to run:**
- ✅ After first deployment
- ✅ After restoring a database backup
- ❌ NOT needed after code updates (configs persist in database)

**Safe to run multiple times** — it just updates the same records.

---

## After Deployment Checklist

| Step | Where | Required? |
|------|-------|-----------|
| Set Captain AI keys | Super Admin → Captain | Only if using AI |
| Set Facebook app | Super Admin → Facebook | Only if using FB/Instagram |
| Set WhatsApp app | Super Admin → WhatsApp Embedded | Only if using WhatsApp |
| Set SMTP | .env file | Yes — needed for email notifications |
| Create admin account | Console or signup page | Yes |
| Make user SuperAdmin | Console: `User.first.update!(type: 'SuperAdmin')` | Yes |

---

## Updating to Latest Version

```bash
# 1. Pull latest from upstream
git fetch upstream
git merge upstream/develop

# 2. If merge conflicts on our 2 modified files:
#    - config/application.rb → keep the custom/ line
#    - 01_inject_enterprise_edition_module.rb → keep the `return nil unless mod` fix

# 3. Install any new dependencies
bundle install
pnpm install

# 4. Run new migrations
bundle exec rails db:migrate

# 5. Rebuild assets (production only)
RAILS_ENV=production bundle exec rails assets:precompile

# 6. Restart services
# Coolify: just push to GitHub, Coolify auto-redeploys
# Manual: sudo systemctl restart chatwoot-web chatwoot-worker
```

**Your enterprise config persists in the database** — no need to re-run `chatwoot:enterprise_setup` after updates.

---

## Troubleshooting

### "add more licenses" banner still showing

```bash
bundle exec rails runner "InstallationConfig.find_or_create_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY').update!(value: 100000)"
```

### Features disappeared after update

The daily hub job shouldn't run because of our `custom/` override. But if it somehow did:

```bash
bundle exec rails chatwoot:enterprise_setup
```

### Facebook/Instagram/WhatsApp channels greyed out

These need OAuth app credentials in Super Admin → App Config. They won't be clickable until you add your Meta/WhatsApp developer app keys.

### Migration errors on fresh install

Use `db:schema:load` instead of `db:migrate` for fresh databases:
```bash
bundle exec rails db:schema:load
```

### `const_get_maybe_false` error

Make sure the fix in `config/initializers/01_inject_enterprise_edition_module.rb` is applied:
```ruby
def const_get_maybe_false(mod, name)
  return nil unless mod
  mod.const_defined?(name, false) && mod.const_get(name, false)
end
```

### Custom overlay not loading

Verify:
1. `custom/` folder exists at project root
2. `config/application.rb` has the `custom/app/**` eager_load_paths line
3. Restart the Rails server (the check happens at boot)

```bash
bundle exec rails runner "puts ChatwootApp.custom?"
# Should print: true
```
