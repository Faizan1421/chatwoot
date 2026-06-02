# Environment Variables Reference

Complete guide for all `.env` variables used in this project.

---

## Required (App won't start without these)

```bash
# Random string for encrypting cookies/sessions
# Generate with: openssl rand -hex 64
SECRET_KEY_BASE=your_64_char_hex_string

# Public URL where users access Chatwoot
# Local: http://localhost:3000
# Production: https://chat.yourdomain.com
FRONTEND_URL=http://localhost:3000

# Database
POSTGRES_HOST=localhost
POSTGRES_USERNAME=chatwoot
POSTGRES_PASSWORD=chatwoot
POSTGRES_DATABASE=chatwoot_dev

# Redis (for caching, job queues, websockets)
REDIS_URL=redis://localhost:6379

# Environment
RAILS_ENV=development
```

---

## Email (SMTP)

Required for sending invitations, confirmations, notifications.

```bash
# SMTP server address
SMTP_ADDRESS=smtpout.secureserver.net

# Port: 465 (SSL) or 587 (STARTTLS)
SMTP_PORT=465

# Your email credentials
SMTP_USERNAME=contact@yourdomain.com
SMTP_PASSWORD=your_password

# Authentication: login, plain, or cram_md5
SMTP_AUTHENTICATION=login

# Domain for HELO check
SMTP_DOMAIN=yourdomain.com

# For port 465 (direct SSL):
SMTP_ENABLE_STARTTLS_AUTO=false
SMTP_SSL=true
SMTP_OPENSSL_VERIFY_MODE=none

# For port 587 (STARTTLS):
# SMTP_ENABLE_STARTTLS_AUTO=true
# SMTP_SSL=
# SMTP_OPENSSL_VERIFY_MODE=peer

# Timeout settings (optional, in seconds)
SMTP_OPEN_TIMEOUT=30
SMTP_READ_TIMEOUT=30

# From address shown in emails
MAILER_SENDER_EMAIL=Chat <noreply@yourdomain.com>
```

### Local Development (skip SMTP entirely)

```bash
# Opens emails in browser instead of sending via SMTP
LETTER_OPENER=true
```

---

## Storage (File Uploads)

### Local (default, good for dev)

```bash
ACTIVE_STORAGE_SERVICE=local
```

### Cloudflare R2

R2 is S3-compatible and much cheaper than AWS S3.

**Setup steps:**
1. Cloudflare Dashboard → R2 → Create a bucket
2. R2 → Manage R2 API Tokens → Create API Token (with read/write access)
3. Copy Access Key ID + Secret Access Key
4. Your account ID is in the Cloudflare dashboard URL

```bash
ACTIVE_STORAGE_SERVICE=s3_compatible
STORAGE_ACCESS_KEY_ID=your_r2_access_key_id
STORAGE_SECRET_ACCESS_KEY=your_r2_secret_access_key
STORAGE_REGION=auto
STORAGE_BUCKET_NAME=chatwoot-uploads
STORAGE_ENDPOINT=https://YOUR_ACCOUNT_ID.r2.cloudflarestorage.com
STORAGE_FORCE_PATH_STYLE=true
```

**R2 pricing:** Free up to 10GB storage + 10 million requests/month.

### AWS S3

```bash
ACTIVE_STORAGE_SERVICE=amazon
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
AWS_REGION=us-east-1
S3_BUCKET_NAME=chatwoot-uploads
```

### Google Cloud Storage

```bash
ACTIVE_STORAGE_SERVICE=google
GCS_PROJECT=your-project-id
GCS_CREDENTIALS=/path/to/credentials.json
GCS_BUCKET=chatwoot-uploads
```

### Azure Blob Storage

```bash
ACTIVE_STORAGE_SERVICE=microsoft
AZURE_STORAGE_ACCOUNT_NAME=your_account
AZURE_STORAGE_ACCESS_KEY=your_key
AZURE_STORAGE_CONTAINER=chatwoot-uploads
```

### DigitalOcean Spaces / Minio / Other S3-Compatible

```bash
ACTIVE_STORAGE_SERVICE=s3_compatible
STORAGE_ACCESS_KEY_ID=your_key
STORAGE_SECRET_ACCESS_KEY=your_secret
STORAGE_REGION=nyc3
STORAGE_BUCKET_NAME=chatwoot-uploads
STORAGE_ENDPOINT=https://nyc3.digitaloceanspaces.com
STORAGE_FORCE_PATH_STYLE=false
```

---

## Security & Telemetry

```bash
# Prevents sending usage data to Chatwoot hub
# Extra safety alongside custom/ overlay
DISABLE_TELEMETRY=true

# Allow/block public account signup
# false = only Super Admin can create accounts
# true = anyone can sign up
ENABLE_ACCOUNT_SIGNUP=false
```

---

## Push Notifications

```bash
# Use Chatwoot's relay for official mobile app notifications
ENABLE_PUSH_RELAY_SERVER=true

# OR use your own Firebase (for custom mobile app)
# FCM_SERVER_KEY=your_firebase_key
# VAPID_PUBLIC_KEY=your_vapid_public
# VAPID_PRIVATE_KEY=your_vapid_private
```

---

## Logging

```bash
# Print logs to terminal (useful in Docker)
RAILS_LOG_TO_STDOUT=true

# Log level: debug, info, warn, error
LOG_LEVEL=info

# Max log file size in MB
LOG_SIZE=500
```

---

## Redis (Advanced)

```bash
# Basic URL
REDIS_URL=redis://localhost:6379

# With password
REDIS_URL=redis://:your_password@localhost:6379

# Redis password (for Docker Compose internal Redis)
REDIS_PASSWORD=your_redis_password

# Redis Sentinel (for high availability)
# REDIS_SENTINELS=sentinel1:26379,sentinel2:26379
# REDIS_SENTINEL_MASTER_NAME=mymaster
```

---

## Database (Advanced)

```bash
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_USERNAME=chatwoot
POSTGRES_PASSWORD=your_password
POSTGRES_DATABASE=chatwoot_production

# Query timeout (default 14 seconds)
# POSTGRES_STATEMENT_TIMEOUT=14s

# Connection pool
RAILS_MAX_THREADS=5
```

---

## Social Channel OAuth (set in Super Admin, NOT .env)

These are configured via Super Admin → App Config after deployment:

| Channel | Keys needed |
|---------|-------------|
| Facebook + Instagram | FB_APP_ID, FB_APP_SECRET, FB_VERIFY_TOKEN |
| WhatsApp | WHATSAPP_APP_ID, WHATSAPP_APP_SECRET, WHATSAPP_CONFIGURATION_ID |
| Slack | SLACK_CLIENT_ID, SLACK_CLIENT_SECRET |
| Google | GOOGLE_OAUTH_CLIENT_ID, GOOGLE_OAUTH_CLIENT_SECRET |
| Microsoft | AZURE_APP_ID, AZURE_APP_SECRET |
| Linear | LINEAR_CLIENT_ID, LINEAR_CLIENT_SECRET |
| Notion | NOTION_CLIENT_ID, NOTION_CLIENT_SECRET |

**Do NOT put these in .env** — manage them from Super Admin UI.

---

## Captain AI (set in Super Admin, NOT .env)

Configured via Super Admin → App Config → Captain:

| Key | Purpose |
|-----|---------|
| CAPTAIN_OPEN_AI_API_KEY | LLM API key |
| CAPTAIN_OPEN_AI_MODEL | Model name (e.g., gpt-4.1-mini) |
| CAPTAIN_OPEN_AI_ENDPOINT | API URL (blank for OpenAI default) |
| CAPTAIN_EMBEDDING_MODEL | Embedding model (default: text-embedding-3-small) |
| CAPTAIN_FIRECRAWL_API_KEY | For document auto-sync |

**Do NOT put these in .env** — manage them from Super Admin UI.

---

## Stripe (for SaaS billing)

```bash
STRIPE_SECRET_KEY=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

---

## Optional Performance

```bash
# Sidekiq worker concurrency
SIDEKIQ_CONCURRENCY=10

# Direct uploads to cloud storage (skips server)
DIRECT_UPLOADS_ENABLED=true

# Rack Attack rate limiting
ENABLE_RACK_ATTACK=true
RACK_ATTACK_LIMIT=300
```

---

## Minimal .env for Local Development

```bash
SECRET_KEY_BASE=local_dev_secret_key_base_replace_with_anything_long
FRONTEND_URL=http://localhost:3000
POSTGRES_HOST=localhost
POSTGRES_USERNAME=chatwoot
POSTGRES_PASSWORD=chatwoot
REDIS_URL=redis://localhost:6379
RAILS_ENV=development
LETTER_OPENER=true
DISABLE_TELEMETRY=true
```

---

## Minimal .env for Production (Coolify/Server)

```bash
SECRET_KEY_BASE=generate_with_openssl_rand_hex_64
FRONTEND_URL=https://chat.yourdomain.com
POSTGRES_HOST=postgres
POSTGRES_USERNAME=chatwoot
POSTGRES_PASSWORD=strong_password_here
POSTGRES_DATABASE=chatwoot_production
REDIS_URL=redis://:redis_password@redis:6379
REDIS_PASSWORD=redis_password
RAILS_ENV=production
NODE_ENV=production
RAILS_LOG_TO_STDOUT=true
ENABLE_ACCOUNT_SIGNUP=false
DISABLE_TELEMETRY=true
ENABLE_PUSH_RELAY_SERVER=true

# Storage (pick one)
ACTIVE_STORAGE_SERVICE=s3_compatible
STORAGE_ACCESS_KEY_ID=r2_key
STORAGE_SECRET_ACCESS_KEY=r2_secret
STORAGE_REGION=auto
STORAGE_BUCKET_NAME=chatwoot-uploads
STORAGE_ENDPOINT=https://ACCOUNT_ID.r2.cloudflarestorage.com
STORAGE_FORCE_PATH_STYLE=true

# Email
SMTP_ADDRESS=smtp.yourdomain.com
SMTP_PORT=465
SMTP_USERNAME=noreply@yourdomain.com
SMTP_PASSWORD=smtp_password
SMTP_AUTHENTICATION=login
SMTP_DOMAIN=yourdomain.com
SMTP_ENABLE_STARTTLS_AUTO=false
SMTP_SSL=true
SMTP_OPENSSL_VERIFY_MODE=none
MAILER_SENDER_EMAIL=Chat <noreply@yourdomain.com>
```
