# Self-Hosted Chatwoot: Full Enterprise Setup Guide

This document explains how to unlock and use all Chatwoot Enterprise features (including Captain AI) on your own self-hosted server — without forking the repository and without breaking future updates.

---

## Table of Contents

1. [How Enterprise Gating Works](#how-enterprise-gating-works)
2. [The Custom Overlay Approach](#the-custom-overlay-approach)
3. [Step-by-Step Setup](#step-by-step-setup)
4. [Captain AI Configuration](#captain-ai-configuration)
5. [Super Admin Configuration](#super-admin-configuration)
6. [Deployment](#deployment)
7. [Updating Chatwoot](#updating-chatwoot)
8. [Troubleshooting](#troubleshooting)
9. [Reference: All Premium Features](#reference-all-premium-features)
10. [Reference: Architecture Overview](#reference-architecture-overview)

---

## How Enterprise Gating Works

Chatwoot uses multiple layers to gate enterprise features:

### Layer 1: Enterprise Directory Detection

```ruby
# lib/chatwoot_app.rb
def self.enterprise?
  return if ENV.fetch('DISABLE_ENTERPRISE', false)
  @enterprise ||= root.join('enterprise').exist?
end
```

If the `enterprise/` folder exists at the project root, the app runs in enterprise mode. This folder is included in the repository by default.

### Layer 2: Installation Pricing Plan

The `INSTALLATION_PRICING_PLAN` value in the `installation_configs` database table determines the plan level. Values: `community` or `enterprise`.

```ruby
# lib/chatwoot_hub.rb
def self.pricing_plan
  return 'community' unless ChatwootApp.enterprise?
  InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN')&.value || 'community'
end
```

### Layer 3: Per-Account Feature Flags

Each account has a `feature_flags` integer column using bit-flags (via FlagShihTzu gem). Features are defined in `config/features.yml`. Features marked `premium: true` are enterprise-only.

### Layer 4: Daily Hub Sync (The Problem)

A daily background job (`Internal::CheckNewVersionsJob`) pings Chatwoot's hub server (`hub.2.chatwoot.com`). The hub returns your actual plan status. The enterprise overlay for this job then:

1. **Overwrites** `INSTALLATION_PRICING_PLAN` with what the hub says (= `community` if you have no license)
2. Runs `ReconcilePlanConfigService` which **disables all premium features** on every account

This is the only thing you need to prevent.

### Layer 5: Frontend Checks

The frontend uses `usePolicy()` composable which checks:
- `window.chatwootConfig.isEnterprise` — is enterprise code present?
- `window.chatwootConfig.enterprisePlanName` — "enterprise" or "community"
- Feature flags enabled on the account
- `PREMIUM_FEATURES` array — shows paywall if premium + not enabled

Once backend config is correct, the frontend automatically unlocks.

---

## The Custom Overlay Approach

Chatwoot has a built-in `custom/` overlay system, identical to the `enterprise/` overlay:

```ruby
# lib/chatwoot_app.rb
def self.custom?
  @custom ||= root.join('custom').exist?
end

def self.extensions
  if custom?
    %w[enterprise custom]
  elsif enterprise?
    %w[enterprise]
  else
    %w[]
  end
end
```

When a `custom/` folder exists:
- `ChatwootApp.extensions` returns `['enterprise', 'custom']`
- Modules in `custom/` are prepended **after** enterprise modules (higher priority)
- You can override any enterprise behavior without touching upstream files

This means: **zero merge conflicts on updates, no fork needed**.

---

## Step-by-Step Setup

### Step 1: Create the Custom Override File

Create the following directory structure at your project root:

```
custom/
  app/
    jobs/
      custom/
        internal/
          check_new_versions_job.rb
```

Create the file:

```ruby
# custom/app/jobs/custom/internal/check_new_versions_job.rb
# frozen_string_literal: true

module Custom::Internal::CheckNewVersionsJob
  def perform
    # Skip plan enforcement from hub.
    # Still check for version updates (harmless).
    @instance_info = ChatwootHub.sync_with_hub
    update_version_info
  end
end
```

**What this does:**
- Overrides the enterprise job's `perform` method
- Still fetches version info (so you know when updates are available)
- Skips `update_plan_info` (no plan reset)
- Skips `reconcile_premium_config_and_features` (no feature stripping)

### Step 2: Set Installation Plan to Enterprise

Open Rails console:

```bash
bundle exec rails console
```

Run:

```ruby
# Set plan to enterprise
InstallationConfig.find_or_create_by(name: 'INSTALLATION_PRICING_PLAN').update!(value: 'enterprise')

# Set deployment environment
InstallationConfig.find_or_create_by(name: 'DEPLOYMENT_ENV').update!(value: 'self-hosted')

# Clear cache
GlobalConfig.clear_cache
```

### Step 3: Enable Premium Features on Your Account

Still in Rails console:

```ruby
account = Account.first  # or Account.find(YOUR_ACCOUNT_ID)

account.enable_features!(
  'sla',
  'audit_logs',
  'custom_roles',
  'disable_branding',
  'captain_integration',
  'captain_integration_v2',
  'custom_tools',
  'csat_review_notes',
  'conversation_required_attributes',
  'channel_voice',
  'saml',
  'companies',
  'advanced_assignment',
  'captain_document_auto_sync',
  'advanced_search',
  'help_center_embedding_search',
  'captain_tasks'
)
```

To enable features on ALL accounts:

```ruby
Account.find_each do |account|
  account.enable_features!(
    'sla', 'audit_logs', 'custom_roles', 'disable_branding',
    'captain_integration', 'captain_integration_v2', 'custom_tools',
    'csat_review_notes', 'conversation_required_attributes',
    'channel_voice', 'saml', 'companies', 'advanced_assignment',
    'captain_document_auto_sync', 'advanced_search',
    'help_center_embedding_search', 'captain_tasks'
  )
end
```

### Step 4: Verify

```ruby
# Check plan
ChatwootHub.pricing_plan
# => "enterprise"

# Check features
Account.first.feature_enabled?('captain_integration')
# => true

Account.first.feature_enabled?('sla')
# => true

# Check enterprise detection
ChatwootApp.enterprise?
# => true

ChatwootApp.custom?
# => true
```

---

## Captain AI Configuration

### Via Rails Console

```ruby
# Required: OpenAI API Key
InstallationConfig.find_or_create_by(name: 'CAPTAIN_OPEN_AI_API_KEY').update!(value: 'sk-your-openai-api-key-here')

# Optional: Model (default: gpt-4.1-mini)
InstallationConfig.find_or_create_by(name: 'CAPTAIN_OPEN_AI_MODEL').update!(value: 'gpt-4o')

# Optional: Custom endpoint (for Azure OpenAI, local LLMs, or any OpenAI-compatible API)
# Default: https://api.openai.com/
InstallationConfig.find_or_create_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT').update!(value: 'https://api.openai.com/')

# Optional: Embedding model (default: text-embedding-3-small)
InstallationConfig.find_or_create_by(name: 'CAPTAIN_EMBEDDING_MODEL').update!(value: 'text-embedding-3-small')

# Optional: FireCrawl API key (for document auto-sync / web scraping)
InstallationConfig.find_or_create_by(name: 'CAPTAIN_FIRECRAWL_API_KEY').update!(value: 'fc-your-firecrawl-key')
```

### Via Super Admin UI (after plan is set to enterprise)

1. Log in as Super Admin
2. Navigate to Settings → App Config → Captain
3. Fill in:
   - **OpenAI API Key** — your `sk-...` key
   - **OpenAI Model** — e.g., `gpt-4o`, `gpt-4.1-mini`, `gpt-4-turbo`
   - **OpenAI API Endpoint** — leave blank for default, or set custom URL
   - **Embedding Model** — leave blank for default
   - **FireCrawl API Key** — optional, for document syncing

### Using Custom/Local LLMs

If you're running a local LLM with an OpenAI-compatible API (like Ollama, vLLM, LiteLLM, LocalAI):

```ruby
InstallationConfig.find_or_create_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT').update!(value: 'http://localhost:11434/v1/')
InstallationConfig.find_or_create_by(name: 'CAPTAIN_OPEN_AI_MODEL').update!(value: 'llama3')
InstallationConfig.find_or_create_by(name: 'CAPTAIN_OPEN_AI_API_KEY').update!(value: 'not-needed')
```

---

## Super Admin Configuration

Once the plan is set to `enterprise`, the Super Admin panel unlocks these config sections:

| Section | What you can configure |
|---------|----------------------|
| **General** | Account signup, Firebase, webhook timeout, file upload size |
| **Captain** | OpenAI key, model, endpoint, embedding model, FireCrawl key |
| **Custom Branding** | Logo, brand name, installation name, URLs, manifest |
| **Facebook** | App ID, verify token, secret |
| **Instagram** | App ID, secret, verify token |
| **TikTok** | App ID, secret |
| **WhatsApp Embedded** | App ID, secret, configuration ID |
| **Slack** | Client ID, secret |
| **Linear** | Client ID, secret |
| **Notion** | Client ID, secret |
| **Google** | OAuth client ID, secret, redirect URI |
| **Microsoft** | Azure App ID, secret |
| **Email** | Inbound domain, account email limits |
| **SAML** | Enable/disable SSO login |
| **Shopify** | Client ID, secret |

### Per-Account Feature Management

Super Admin → Accounts → (select account) → Features tab

Here you'll see checkboxes for all features. With enterprise plan active, all checkboxes are editable (on community plan they're disabled/greyed out).

---

## Deployment

### Prerequisites

- Ruby (version in `.ruby-version` — currently 3.3.x)
- Node.js 20+
- PostgreSQL 14+
- Redis 7+
- Sidekiq (for background jobs)

### Environment Variables (.env)

```bash
# === Core ===
RAILS_ENV=production
SECRET_KEY_BASE=generate_with_bundle_exec_rails_secret
FRONTEND_URL=https://chat.yourdomain.com

# === Database ===
POSTGRES_HOST=localhost
POSTGRES_USERNAME=chatwoot
POSTGRES_PASSWORD=your_secure_password
POSTGRES_DATABASE=chatwoot_production

# === Redis ===
REDIS_URL=redis://localhost:6379

# === Storage ===
ACTIVE_STORAGE_SERVICE=local
# For S3: ACTIVE_STORAGE_SERVICE=amazon
# AWS_ACCESS_KEY_ID=...
# AWS_SECRET_ACCESS_KEY=...
# AWS_REGION=...
# S3_BUCKET_NAME=...

# === Email (SMTP) ===
SMTP_ADDRESS=smtp.yourdomain.com
SMTP_PORT=587
SMTP_USERNAME=noreply@yourdomain.com
SMTP_PASSWORD=your_smtp_password
MAILER_SENDER_EMAIL=Chatwoot <noreply@yourdomain.com>

# === Optional ===
# DISABLE_TELEMETRY=true  (optional extra safety, but not needed with custom/ overlay)
```

### Deploy Steps

```bash
# 1. Clone repository
git clone https://github.com/chatwoot/chatwoot.git
cd chatwoot

# 2. Create custom overlay
mkdir -p custom/app/jobs/custom/internal/
# Place check_new_versions_job.rb (from Step 1 above)

# 3. Install dependencies
bundle install
pnpm install

# 4. Setup database
bundle exec rails db:create
bundle exec rails db:migrate
bundle exec rails db:seed  # seeds installation_configs

# 5. Precompile assets
bundle exec rails assets:precompile

# 6. Start services
# Web server
bundle exec puma -C config/puma.rb

# Background workers (required for Captain, email, etc.)
bundle exec sidekiq -C config/sidekiq.yml

# 7. Run one-time setup (Steps 2-4 from setup section)
bundle exec rails console
# ... run the InstallationConfig and feature enable commands ...
```

### Docker Deployment

If using Docker, add the custom folder to your build:

```dockerfile
# In your Dockerfile or docker-compose override
COPY custom/ /app/custom/
```

Or mount it as a volume:

```yaml
# docker-compose.override.yml
services:
  web:
    volumes:
      - ./custom:/app/custom
  worker:
    volumes:
      - ./custom:/app/custom
```

After container starts:

```bash
docker exec -it chatwoot-web bundle exec rails console
# Run the one-time config commands
```

### Reverse Proxy (Nginx)

```nginx
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

---

## Updating Chatwoot

### If you kept `custom/` outside version control (gitignored):

```bash
git pull origin main   # or whatever upstream branch
bundle install
pnpm install
bundle exec rails db:migrate
bundle exec rails assets:precompile
# Restart services
```

Zero conflicts. Your `custom/` folder is untouched.

### If you committed `custom/` to your own branch:

```bash
git fetch upstream
git merge upstream/main
# No conflicts because custom/ doesn't exist upstream
bundle install
pnpm install
bundle exec rails db:migrate
bundle exec rails assets:precompile
# Restart services
```

### After update: re-verify

```bash
bundle exec rails console
```

```ruby
# Confirm plan is still enterprise
ChatwootHub.pricing_plan
# => "enterprise"

# Confirm features still enabled
Account.first.feature_enabled?('captain_integration')
# => true
```

If a new Chatwoot version adds new premium features, enable them:

```ruby
# Check what's new in config/features.yml marked premium: true
# Then enable on your account:
account = Account.first
account.enable_features!('new_feature_name')
```

---

## Troubleshooting

### Features disappeared after restart

The daily job might have run before your custom overlay loaded. Re-run:

```ruby
InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN').update!(value: 'enterprise')
Account.first.enable_features!('sla', 'captain_integration', ...)  # re-enable all
GlobalConfig.clear_cache
```

Then verify `custom/` is loading:

```ruby
ChatwootApp.custom?
# Must return true
```

### Super Admin pages show community restrictions

Clear browser cache and confirm:

```ruby
ChatwootHub.pricing_plan
# Must return "enterprise", not "community"
```

### Captain AI not responding

1. Verify API key is set:
```ruby
InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value
# Should show your key
```

2. Verify feature is enabled:
```ruby
Account.first.feature_enabled?('captain_integration')
# => true
```

3. Check Sidekiq is running (Captain uses background jobs)

4. Check Rails logs for OpenAI API errors

### Custom overlay not loading

Verify directory structure is exactly:

```
chatwoot/
  custom/
    app/
      jobs/
        custom/
          internal/
            check_new_versions_job.rb
```

The module name must match: `Custom::Internal::CheckNewVersionsJob`

Restart the Rails server after creating the `custom/` directory (it's checked once at boot).

### New accounts don't have premium features

New accounts get default features from `InstallationConfig` named `ACCOUNT_LEVEL_FEATURE_DEFAULTS`. Set it to include premium features:

```ruby
defaults = [
  { name: 'sla', enabled: true },
  { name: 'audit_logs', enabled: true },
  { name: 'custom_roles', enabled: true },
  { name: 'captain_integration', enabled: true },
  { name: 'captain_integration_v2', enabled: true },
  { name: 'custom_tools', enabled: true },
  { name: 'disable_branding', enabled: true },
  { name: 'csat_review_notes', enabled: true },
  { name: 'conversation_required_attributes', enabled: true },
  { name: 'channel_voice', enabled: true },
  { name: 'saml', enabled: true },
  { name: 'companies', enabled: true },
  { name: 'advanced_assignment', enabled: true },
  { name: 'captain_document_auto_sync', enabled: true },
  { name: 'advanced_search', enabled: true },
  { name: 'captain_tasks', enabled: true }
]

InstallationConfig.find_or_create_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS').update!(value: defaults)
```

---

## Reference: All Premium Features

From `config/features.yml` (features with `premium: true`):

| Feature Key | Display Name | Description |
|-------------|-------------|-------------|
| `disable_branding` | Disable Branding | Remove Chatwoot branding from widget/emails |
| `audit_logs` | Audit Logs | Track account activities |
| `custom_tools` | Custom Tools | Captain custom tools |
| `sla` | SLA | Service Level Agreements |
| `help_center_embedding_search` | Help Center Embedding Search | AI-powered help center search |
| `captain_integration` | Captain | AI assistant (v1) |
| `custom_roles` | Custom Roles | Define custom agent roles |
| `captain_v1_action_classifier` | Captain V1 Action Classifier | Internal AI classifier |
| `channel_voice` | Voice Channel | Voice/phone channel support |
| `captain_integration_v2` | Captain V2 | AI assistant (v2) |
| `captain_document_auto_sync` | Captain Document Auto Sync | Auto-sync knowledge base |
| `advanced_search` | Advanced Search | OpenSearch-powered search |
| `saml` | SAML | SSO via SAML |
| `advanced_search_indexing` | Advanced Search Indexing | Index for advanced search |
| `companies` | Companies | Company/organization management |
| `csat_review_notes` | CSAT Review Notes | Notes on CSAT reviews |
| `conversation_required_attributes` | Required Conversation Attributes | Mandatory fields on conversations |
| `advanced_assignment` | Advanced Assignment | Advanced agent assignment rules |

---

## Reference: Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                   Chatwoot App                        │
├─────────────────────────────────────────────────────┤
│                                                       │
│  app/          ← OSS base code                       │
│                                                       │
│  enterprise/   ← Enterprise overlay (prepend_mod)    │
│                   Loaded if enterprise/ dir exists    │
│                                                       │
│  custom/       ← Your overlay (prepend_mod)          │
│                   Loaded AFTER enterprise/            │
│                   Highest priority                    │
│                                                       │
├─────────────────────────────────────────────────────┤
│                                                       │
│  InstallationConfig (DB table)                       │
│  ├── INSTALLATION_PRICING_PLAN = "enterprise"        │
│  ├── DEPLOYMENT_ENV = "self-hosted"                  │
│  ├── CAPTAIN_OPEN_AI_API_KEY = "sk-..."             │
│  ├── CAPTAIN_OPEN_AI_MODEL = "gpt-4o"              │
│  └── ...                                             │
│                                                       │
│  Account.feature_flags (bit column)                  │
│  ├── sla = true                                      │
│  ├── captain_integration = true                      │
│  ├── audit_logs = true                               │
│  └── ...                                             │
│                                                       │
├─────────────────────────────────────────────────────┤
│                                                       │
│  Daily Job Flow:                                     │
│                                                       │
│  TriggerDailyScheduledItemsJob                       │
│       ↓                                              │
│  CheckNewVersionsJob                                 │
│       ↓                                              │
│  Enterprise::CheckNewVersionsJob (prepended)         │
│       ↓                                              │
│  Custom::CheckNewVersionsJob (YOUR override)         │
│       → Only runs update_version_info                │
│       → Skips update_plan_info                       │
│       → Skips reconcile_premium_config               │
│                                                       │
└─────────────────────────────────────────────────────┘
```

### Method Resolution Order

```
Custom::Internal::CheckNewVersionsJob    ← wins (your code)
  ↓ super
Enterprise::Internal::CheckNewVersionsJob
  ↓ super
Internal::CheckNewVersionsJob            ← base OSS class
```

Because `custom/` modules are prepended last, they have the highest priority in Ruby's method resolution order. Your single-file override effectively short-circuits the enterprise plan enforcement.

---

## Quick Reference: One-Page Setup

```bash
# 1. Create override (one file)
mkdir -p custom/app/jobs/custom/internal/
cat > custom/app/jobs/custom/internal/check_new_versions_job.rb << 'RUBY'
module Custom::Internal::CheckNewVersionsJob
  def perform
    @instance_info = ChatwootHub.sync_with_hub
    update_version_info
  end
end
RUBY

# 2. Configure (one-time in rails console)
bundle exec rails console
```

```ruby
# Plan
InstallationConfig.find_or_create_by(name: 'INSTALLATION_PRICING_PLAN').update!(value: 'enterprise')
InstallationConfig.find_or_create_by(name: 'DEPLOYMENT_ENV').update!(value: 'self-hosted')

# AI
InstallationConfig.find_or_create_by(name: 'CAPTAIN_OPEN_AI_API_KEY').update!(value: 'sk-YOUR-KEY')
InstallationConfig.find_or_create_by(name: 'CAPTAIN_OPEN_AI_MODEL').update!(value: 'gpt-4o')

# Features
Account.find_each do |a|
  a.enable_features!('sla','audit_logs','custom_roles','disable_branding','captain_integration',
    'captain_integration_v2','custom_tools','csat_review_notes','conversation_required_attributes',
    'channel_voice','saml','companies','advanced_assignment','captain_document_auto_sync',
    'advanced_search','help_center_embedding_search','captain_tasks')
end

GlobalConfig.clear_cache
```

```bash
# 3. Done. Manage everything from Super Admin UI going forward.
```
