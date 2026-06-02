# Deploying Chatwoot Enterprise on Coolify

Complete guide to deploy Chatwoot with all enterprise features on Coolify, with clean update path for future versions.

---

## Table of Contents

1. [Strategy Overview](#strategy-overview)
2. [Prepare Your Repository](#prepare-your-repository)
3. [Coolify Setup](#coolify-setup)
4. [Post-Deploy: Enable Enterprise](#post-deploy-enable-enterprise)
5. [Updating to New Versions](#updating-to-new-versions)
6. [Complete File Reference](#complete-file-reference)
7. [Environment Variables Reference](#environment-variables-reference)

---

## Strategy Overview

```
GitHub (your private repo)
├── Fork of chatwoot/chatwoot (or private mirror)
├── custom/                          ← your only addition (1 file)
│   └── app/jobs/custom/internal/
│       └── check_new_versions_job.rb
└── Everything else = upstream unchanged
```

**Why this works cleanly:**
- Chatwoot has a built-in `custom/` overlay system (like plugins)
- The `custom/` folder is not in upstream, so git pull/merge never conflicts
- Coolify auto-builds from your repo using the existing `docker/Dockerfile`
- One-time config via rails console after first deploy
- Future updates = just merge upstream, zero conflicts

---

## Prepare Your Repository

### Option A: Fork (recommended for Coolify)

```bash
# 1. Fork chatwoot/chatwoot on GitHub (make it PRIVATE)
#    Go to https://github.com/chatwoot/chatwoot → Fork → make private

# 2. Clone your fork locally
git clone git@github.com:YOUR_USERNAME/chatwoot.git
cd chatwoot

# 3. Add upstream remote for future updates
git remote add upstream https://github.com/chatwoot/chatwoot.git

# 4. Create the custom overlay
mkdir -p custom/app/jobs/custom/internal/
```

### Option B: Private mirror (if you don't want a GitHub fork)

```bash
# 1. Create a new private repo on GitHub/GitLab
# 2. Clone upstream and push to your private repo
git clone https://github.com/chatwoot/chatwoot.git
cd chatwoot
git remote rename origin upstream
git remote add origin git@github.com:YOUR_USERNAME/chatwoot-private.git
git push -u origin main

# 3. Create the custom overlay
mkdir -p custom/app/jobs/custom/internal/
```

### Create the Override File

Create `custom/app/jobs/custom/internal/check_new_versions_job.rb`:

```ruby
# frozen_string_literal: true

# This override prevents the daily hub sync from resetting
# INSTALLATION_PRICING_PLAN back to 'community'.
# It still fetches version info so you know when updates are available.
module Custom::Internal::CheckNewVersionsJob
  def perform
    @instance_info = ChatwootHub.sync_with_hub
    update_version_info
  end
end
```

### Create a Setup Rake Task (optional but convenient)

Create `custom/lib/tasks/custom_setup.rake`:

```ruby
# frozen_string_literal: true

namespace :custom do
  desc 'Enable enterprise plan and all premium features'
  task setup_enterprise: :environment do
    puts '🔧 Setting installation plan to enterprise...'
    InstallationConfig.find_or_create_by(name: 'INSTALLATION_PRICING_PLAN').update!(value: 'enterprise')
    InstallationConfig.find_or_create_by(name: 'DEPLOYMENT_ENV').update!(value: 'self-hosted')

    puts '🔧 Enabling premium features on all accounts...'
    premium_features = %w[
      sla audit_logs custom_roles disable_branding
      captain_integration captain_integration_v2 custom_tools
      csat_review_notes conversation_required_attributes
      channel_voice saml companies advanced_assignment
      captain_document_auto_sync advanced_search
      help_center_embedding_search captain_tasks
    ]

    Account.find_each do |account|
      account.enable_features!(*premium_features)
      puts "   ✅ Enabled for Account ##{account.id} (#{account.name})"
    end

    GlobalConfig.clear_cache
    puts '🎉 Done! All enterprise features enabled.'
  end

  desc 'Configure Captain AI with OpenAI key'
  task :setup_captain, [:api_key, :model] => :environment do |_t, args|
    api_key = args[:api_key] || ENV.fetch('CAPTAIN_OPEN_AI_API_KEY', nil)
    model = args[:model] || ENV.fetch('CAPTAIN_OPEN_AI_MODEL', 'gpt-4o')

    if api_key.blank?
      puts '❌ Please provide an API key:'
      puts '   bundle exec rails custom:setup_captain[sk-your-key-here]'
      puts '   OR set CAPTAIN_OPEN_AI_API_KEY env var'
      exit 1
    end

    InstallationConfig.find_or_create_by(name: 'CAPTAIN_OPEN_AI_API_KEY').update!(value: api_key)
    InstallationConfig.find_or_create_by(name: 'CAPTAIN_OPEN_AI_MODEL').update!(value: model)

    endpoint = ENV.fetch('CAPTAIN_OPEN_AI_ENDPOINT', '')
    if endpoint.present?
      InstallationConfig.find_or_create_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT').update!(value: endpoint)
    end

    GlobalConfig.clear_cache
    puts "🤖 Captain AI configured: model=#{model}"
  end
end
```

> **Note:** Rails automatically loads rake tasks from `lib/tasks/` in any directory in the load path. Since `custom/` is loaded as an extension, place this at `custom/lib/tasks/custom_setup.rake`. If it doesn't get picked up, you can alternatively place it at `lib/tasks/custom_setup.rake` in the main tree.

### Commit and Push

```bash
git add custom/
git commit -m "feat: add custom overlay for enterprise self-hosting"
git push origin main
```

---

## Coolify Setup

### Step 1: Create New Resource

1. Go to your Coolify dashboard
2. Click **+ New Resource** → **Docker Compose**
3. Connect your GitHub/GitLab account (or use deploy key for private repo)
4. Select your chatwoot repository and branch (`main`)

### Step 2: Docker Compose Configuration

In Coolify, use this docker-compose config (paste in the Docker Compose editor):

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
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:3000/auth/sign_in || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3

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

### Step 3: Environment Variables

In Coolify's **Environment Variables** section for the service, add:

```bash
# === Core ===
SECRET_KEY_BASE=<generate: run `openssl rand -hex 64` on your machine>
FRONTEND_URL=https://chat.yourdomain.com
RAILS_ENV=production
NODE_ENV=production

# === Database ===
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_USERNAME=chatwoot
POSTGRES_PASSWORD=<generate-a-strong-password>
POSTGRES_DATABASE=chatwoot_production

# === Redis ===
REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379
REDIS_PASSWORD=<generate-a-strong-password>

# === Email (SMTP) ===
SMTP_ADDRESS=smtp.yourdomain.com
SMTP_PORT=587
SMTP_USERNAME=noreply@yourdomain.com
SMTP_PASSWORD=your-smtp-password
SMTP_AUTHENTICATION=plain
SMTP_ENABLE_STARTTLS_AUTO=true
MAILER_SENDER_EMAIL=Chatwoot <noreply@yourdomain.com>

# === Storage ===
ACTIVE_STORAGE_SERVICE=local
# For S3:
# ACTIVE_STORAGE_SERVICE=amazon
# AWS_ACCESS_KEY_ID=...
# AWS_SECRET_ACCESS_KEY=...
# AWS_REGION=us-east-1
# S3_BUCKET_NAME=chatwoot-storage

# === Optional ===
RAILS_LOG_TO_STDOUT=true
LOG_LEVEL=info
ENABLE_ACCOUNT_SIGNUP=false
```

### Step 4: Domain Configuration

1. In Coolify, go to the service's **Domains** tab
2. Set your domain: `chat.yourdomain.com`
3. Map it to port `3000` (the rails service)
4. Enable HTTPS (Coolify handles Let's Encrypt automatically)

### Step 5: Deploy

Click **Deploy**. Coolify will:
1. Clone your repo
2. Build the Docker image using `docker/Dockerfile` (includes `custom/` folder)
3. Start all services
4. Run migrations automatically (via the entrypoint script)

### Step 6: First-Time Database Setup

After the first deploy, you need to run migrations and seed the database. In Coolify:

1. Go to your **rails** service → **Terminal** (or use Coolify's execute command feature)
2. Run:

```bash
bundle exec rails db:prepare
bundle exec rails db:seed
```

---

## Post-Deploy: Enable Enterprise

After the first successful deploy, exec into the rails container:

### Via Coolify Terminal

Go to your rails service → Terminal, then run:

```bash
bundle exec rails console
```

### Run the Setup

```ruby
# === Step 1: Set plan to enterprise ===
InstallationConfig.find_or_create_by(name: 'INSTALLATION_PRICING_PLAN').update!(value: 'enterprise')
InstallationConfig.find_or_create_by(name: 'DEPLOYMENT_ENV').update!(value: 'self-hosted')

# === Step 2: Enable all premium features ===
premium_features = %w[
  sla audit_logs custom_roles disable_branding
  captain_integration captain_integration_v2 custom_tools
  csat_review_notes conversation_required_attributes
  channel_voice saml companies advanced_assignment
  captain_document_auto_sync advanced_search
  help_center_embedding_search captain_tasks
]

Account.find_each do |account|
  account.enable_features!(*premium_features)
end

# === Step 3: Configure Captain AI ===
InstallationConfig.find_or_create_by(name: 'CAPTAIN_OPEN_AI_API_KEY').update!(value: 'sk-your-openai-key')
InstallationConfig.find_or_create_by(name: 'CAPTAIN_OPEN_AI_MODEL').update!(value: 'gpt-4o')
# Optional: custom endpoint for Azure/local LLM
# InstallationConfig.find_or_create_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT').update!(value: 'http://your-llm:8080/v1/')

# === Step 4: Set defaults for future new accounts ===
defaults = premium_features.map { |f| { 'name' => f, 'enabled' => true } }
existing = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
if existing
  merged = (existing.value + defaults).uniq { |h| h['name'] }
  existing.update!(value: merged)
else
  InstallationConfig.create!(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS', value: defaults, locked: true)
end

# === Step 5: Clear cache ===
GlobalConfig.clear_cache

puts "✅ Enterprise setup complete!"
```

### Or If You Created the Rake Task

```bash
bundle exec rails custom:setup_enterprise
bundle exec rails custom:setup_captain[sk-your-openai-key,gpt-4o]
```

### Verify

```ruby
ChatwootHub.pricing_plan          # => "enterprise"
ChatwootApp.enterprise?           # => true
ChatwootApp.custom?               # => true
Account.first.feature_enabled?('captain_integration')  # => true
Account.first.feature_enabled?('sla')                  # => true
```

After this, everything is manageable from the **Super Admin UI** — you don't need to touch the console again unless you want to.

---

## Updating to New Versions

### When Chatwoot releases a new version:

```bash
# 1. Fetch latest from upstream
git fetch upstream

# 2. Merge into your main branch
git checkout main
git merge upstream/main
# No conflicts — custom/ doesn't exist upstream

# 3. Push to your repo (triggers Coolify rebuild)
git push origin main
```

### Coolify will automatically:
1. Detect the push (if webhook is configured) or manually trigger redeploy
2. Rebuild the Docker image with your `custom/` overlay included
3. Restart services
4. Run migrations (via entrypoint)

### After update — if new premium features were added:

Exec into the container and enable them:

```bash
bundle exec rails console
```

```ruby
# Check for new premium features
new_features = YAML.safe_load(File.read(Rails.root.join('config/features.yml')))
  .select { |f| f['premium'] }
  .pluck('name')

# Enable any new ones
Account.find_each do |account|
  account.enable_features!(*new_features)
end

GlobalConfig.clear_cache
```

### Automating updates with Coolify webhooks:

1. In Coolify → your service → **Webhooks** tab
2. Copy the deploy webhook URL
3. In your GitHub repo → Settings → Webhooks → add the Coolify webhook URL
4. Now every push to `main` auto-deploys

---

## Complete File Reference

### Your repo structure (only additions shown):

```
chatwoot/
├── custom/
│   ├── app/
│   │   └── jobs/
│   │       └── custom/
│   │           └── internal/
│   │               └── check_new_versions_job.rb   ← prevents plan reset
│   └── lib/
│       └── tasks/
│           └── custom_setup.rake                    ← optional convenience tasks
├── docker/
│   └── Dockerfile                                   ← unchanged, already builds custom/
├── enterprise/                                      ← unchanged, already in repo
└── ... (everything else unchanged)
```

### File: `custom/app/jobs/custom/internal/check_new_versions_job.rb`

```ruby
# frozen_string_literal: true

module Custom::Internal::CheckNewVersionsJob
  def perform
    @instance_info = ChatwootHub.sync_with_hub
    update_version_info
  end
end
```

### File: `custom/lib/tasks/custom_setup.rake` (optional)

```ruby
# frozen_string_literal: true

namespace :custom do
  desc 'Enable enterprise plan and all premium features'
  task setup_enterprise: :environment do
    puts '🔧 Setting installation plan to enterprise...'
    InstallationConfig.find_or_create_by(name: 'INSTALLATION_PRICING_PLAN').update!(value: 'enterprise')
    InstallationConfig.find_or_create_by(name: 'DEPLOYMENT_ENV').update!(value: 'self-hosted')

    puts '🔧 Enabling premium features on all accounts...'
    premium_features = %w[
      sla audit_logs custom_roles disable_branding
      captain_integration captain_integration_v2 custom_tools
      csat_review_notes conversation_required_attributes
      channel_voice saml companies advanced_assignment
      captain_document_auto_sync advanced_search
      help_center_embedding_search captain_tasks
    ]

    Account.find_each do |account|
      account.enable_features!(*premium_features)
      puts "   ✅ Enabled for Account ##{account.id} (#{account.name})"
    end

    # Set defaults for new accounts
    defaults = premium_features.map { |f| { 'name' => f, 'enabled' => true } }
    config = InstallationConfig.find_or_initialize_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    merged = ((config.value || []) + defaults).uniq { |h| h['name'] }
    config.update!(value: merged, locked: true)

    GlobalConfig.clear_cache
    puts '🎉 Done! All enterprise features enabled.'
  end

  desc 'Configure Captain AI: rails custom:setup_captain[sk-key,gpt-4o]'
  task :setup_captain, [:api_key, :model] => :environment do |_t, args|
    api_key = args[:api_key] || ENV.fetch('CAPTAIN_OPEN_AI_API_KEY', nil)
    model = args[:model] || ENV.fetch('CAPTAIN_OPEN_AI_MODEL', 'gpt-4o')

    abort('❌ Provide API key: rails custom:setup_captain[sk-your-key]') if api_key.blank?

    InstallationConfig.find_or_create_by(name: 'CAPTAIN_OPEN_AI_API_KEY').update!(value: api_key)
    InstallationConfig.find_or_create_by(name: 'CAPTAIN_OPEN_AI_MODEL').update!(value: model)

    endpoint = ENV.fetch('CAPTAIN_OPEN_AI_ENDPOINT', '')
    InstallationConfig.find_or_create_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT').update!(value: endpoint) if endpoint.present?

    GlobalConfig.clear_cache
    puts "🤖 Captain configured: model=#{model}"
  end
end
```

---

## Environment Variables Reference

### Required

| Variable | Example | Description |
|----------|---------|-------------|
| `SECRET_KEY_BASE` | `openssl rand -hex 64` | Rails secret key |
| `FRONTEND_URL` | `https://chat.yourdomain.com` | Your public URL |
| `POSTGRES_HOST` | `postgres` | DB host (service name in compose) |
| `POSTGRES_USERNAME` | `chatwoot` | DB user |
| `POSTGRES_PASSWORD` | (strong password) | DB password |
| `POSTGRES_DATABASE` | `chatwoot_production` | DB name |
| `REDIS_URL` | `redis://:pass@redis:6379` | Redis connection URL |
| `REDIS_PASSWORD` | (strong password) | Redis password |
| `SMTP_ADDRESS` | `smtp.gmail.com` | SMTP server |
| `SMTP_PORT` | `587` | SMTP port |
| `SMTP_USERNAME` | `you@gmail.com` | SMTP user |
| `SMTP_PASSWORD` | (app password) | SMTP password |
| `MAILER_SENDER_EMAIL` | `Chat <noreply@you.com>` | From address |

### Optional

| Variable | Default | Description |
|----------|---------|-------------|
| `RAILS_LOG_TO_STDOUT` | `true` | Log to stdout (for Docker) |
| `LOG_LEVEL` | `info` | Rails log level |
| `ENABLE_ACCOUNT_SIGNUP` | `false` | Allow public signup |
| `ACTIVE_STORAGE_SERVICE` | `local` | File storage backend |
| `DISABLE_TELEMETRY` | — | Skip metrics in hub ping (optional extra safety) |
| `RAILS_MAX_THREADS` | `5` | Puma threads |
| `SIDEKIQ_CONCURRENCY` | `10` | Sidekiq worker threads |

### Captain AI (set via Super Admin after deploy, NOT env vars)

These are stored in the database (`installation_configs` table), managed from Super Admin UI:

| Config Name | Default | Description |
|-------------|---------|-------------|
| `CAPTAIN_OPEN_AI_API_KEY` | — | Your OpenAI API key |
| `CAPTAIN_OPEN_AI_MODEL` | `gpt-4.1-mini` | Model to use |
| `CAPTAIN_OPEN_AI_ENDPOINT` | `https://api.openai.com/` | API endpoint |
| `CAPTAIN_EMBEDDING_MODEL` | `text-embedding-3-small` | Embedding model |
| `CAPTAIN_FIRECRAWL_API_KEY` | — | FireCrawl key for doc sync |

---

## Quick Summary

```
1. Fork/mirror repo (private) ─────────────────────── one time
2. Add custom/ folder (1 file) ─────────────────────── one time
3. Push to your repo ──────────────────────────────── one time
4. Create Coolify service (Docker Compose) ─────────── one time
5. Set env vars in Coolify ─────────────────────────── one time
6. Deploy ──────────────────────────────────────────── one time
7. Exec into container, run enterprise setup ───────── one time
8. Configure Captain from Super Admin UI ───────────── one time

Future updates:
   git fetch upstream && git merge upstream/main && git push
   → Coolify auto-redeploys, zero conflicts
```
