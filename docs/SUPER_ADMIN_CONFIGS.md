# Super Admin Configuration Reference

## Accessing Super Admin

URL: `https://yourdomain.com/super_admin`

Only users with `type: 'SuperAdmin'` can access this panel.

---

## App Config (Super Admin → Settings → App Config)

These are the main config sections visible in the Settings page. They only appear when the plan is set to `enterprise`.

| Section | Keys | Purpose |
|---------|------|---------|
| **General** | `ENABLE_ACCOUNT_SIGNUP`, `FIREBASE_*`, `WEBHOOK_*`, `FILE_SIZE_LIMIT` | Core installation settings |
| **Captain** | `CAPTAIN_OPEN_AI_API_KEY`, `CAPTAIN_OPEN_AI_MODEL`, `CAPTAIN_OPEN_AI_ENDPOINT`, `CAPTAIN_EMBEDDING_MODEL`, `CAPTAIN_FIRECRAWL_API_KEY` | AI configuration |
| **Custom Branding** | `LOGO`, `LOGO_DARK`, `BRAND_NAME`, `INSTALLATION_NAME`, `BRAND_URL`, `WIDGET_BRAND_URL`, `TERMS_URL`, `PRIVACY_URL` | White-labeling |
| **Facebook** | `FB_APP_ID`, `FB_VERIFY_TOKEN`, `FB_APP_SECRET` | Facebook Messenger channel |
| **Instagram** | `IG_APP_ID`, `IG_APP_SECRET`, `IG_VERIFY_TOKEN` | Instagram DM channel |
| **TikTok** | `TIKTOK_APP_ID`, `TIKTOK_APP_SECRET` | TikTok channel |
| **WhatsApp Embedded** | `WHATSAPP_APP_ID`, `WHATSAPP_APP_SECRET`, `WHATSAPP_CONFIGURATION_ID` | WhatsApp Cloud API channel |
| **Slack** | `SLACK_CLIENT_ID`, `SLACK_CLIENT_SECRET` | Slack integration |
| **Linear** | `LINEAR_CLIENT_ID`, `LINEAR_CLIENT_SECRET` | Linear issue tracking |
| **Notion** | `NOTION_CLIENT_ID`, `NOTION_CLIENT_SECRET` | Notion integration |
| **Google** | `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET`, `GOOGLE_OAUTH_CALLBACK_URL` | Google login / email |
| **Microsoft** | `AZURE_APP_ID`, `AZURE_APP_SECRET` | Microsoft/Outlook integration |
| **Email** | `MAILER_INBOUND_EMAIL_DOMAIN`, `ACCOUNT_EMAIL_LIMITS` | Email channel settings |
| **SAML** | Enable/disable SAML SSO | SSO configuration |
| **Shopify** | `SHOPIFY_CLIENT_ID`, `SHOPIFY_CLIENT_SECRET` | Shopify integration |

---

## Installation Configs (Super Admin → Installation Configs)

These are ALL the internal configs stored in the `installation_configs` database table. Some are visible in App Config UI, some are hidden and only editable here.
<!-- example : http://localhost:3000/super_admin/installation_configs -->
### Hidden/Important Configs (not in App Config UI)

| Key | What it does | Default | Our value |
|-----|-------------|---------|-----------|
| `INSTALLATION_PRICING_PLAN` | Sets the plan: `community` or `enterprise` | `community` | `enterprise` |
| `INSTALLATION_PRICING_PLAN_QUANTITY` | Max users allowed on the installation | `0` | `100000` |
| `DEPLOYMENT_ENV` | `cloud` or `self-hosted` | — | `self-hosted` |
| `ACCOUNT_LEVEL_FEATURE_DEFAULTS` | Default features for NEW accounts | basic features | all premium features |
| `CHATWOOT_SUPPORT_WEBSITE_TOKEN` | Token for Chatwoot support widget | — | ignore |
| `CHATWOOT_SUPPORT_IDENTIFIER_HASH` | Support identifier | — | ignore |
| `CHATWOOT_SUPPORT_SCRIPT_URL` | Support script URL | — | ignore |

### Captain AI Configs

| Key | What it does | Example |
|-----|-------------|---------|
| `CAPTAIN_OPEN_AI_API_KEY` | API key for LLM | `sk-...` or OpenRouter key |
| `CAPTAIN_OPEN_AI_MODEL` | Model to use for chat | `gpt-4.1-mini`, `deepseek/deepseek-chat` |
| `CAPTAIN_OPEN_AI_ENDPOINT` | API endpoint URL | blank for OpenAI, or `https://openrouter.ai/api/v1` |
| `CAPTAIN_EMBEDDING_MODEL` | Model for document embeddings | `text-embedding-3-small` |
| `CAPTAIN_FIRECRAWL_API_KEY` | FireCrawl key for web scraping/doc sync | `fc-...` |
| `CAPTAIN_CLOUD_PLAN_LIMITS` | Credit limits per plan (SaaS only) | JSON object |

### Billing/Plan Configs (for SaaS)

| Key | What it does | When to use |
|-----|-------------|-------------|
| `CHATWOOT_CLOUD_PLANS` | Define plan tiers with Stripe product IDs | Only if running as SaaS with Stripe |
| `CAPTAIN_CLOUD_PLAN_LIMITS` | AI credit limits per plan | Only if enforcing credits per plan |

---

## Per-Account Settings (Super Admin → Accounts → click account)

| Tab/Field | What it does |
|-----------|-------------|
| **Features** | Toggle premium features on/off per account |
| **Edit → Custom Attributes** | JSON field — set `subscribed_quantity` for agent seat limit |
| **Edit → Limits** | JSON field — set `agents`, `inboxes`, `captain_responses`, etc. |
| **Seed** | Generate sample test data for the account |
| **Reset Cache** | Clear cached data for the account |

### Account Limits (JSON in `limits` column)

```json
{
  "agents": 100,
  "inboxes": 50,
  "captain_responses": 5000,
  "captain_documents": 200,
  "emails": 1000
}
```

If empty/null → defaults to 100,000 (effectively unlimited on self-hosted).

### Account Custom Attributes (JSON)

```json
{
  "subscribed_quantity": 10,
  "plan_name": "starter"
}
```

- `subscribed_quantity` — max agents this account can have
- `plan_name` — display name of their plan (set by Stripe on cloud)

---

## Quick Reference: What Controls What

| Behavior | Controlled by |
|----------|--------------|
| "Enterprise plan" badge | `INSTALLATION_PRICING_PLAN = enterprise` |
| "Add more licenses" banner gone | `INSTALLATION_PRICING_PLAN_QUANTITY = 100000` |
| Premium features visible | Account feature flags (Features tab) |
| Agent seat limit per account | `custom_attributes.subscribed_quantity` |
| Captain AI works | `CAPTAIN_OPEN_AI_API_KEY` is set |
| Facebook/Instagram channels enabled | `FB_APP_ID` + `FB_APP_SECRET` set |
| WhatsApp channel enabled | `WHATSAPP_APP_ID` + `WHATSAPP_APP_SECRET` set |
| New accounts get premium features | `ACCOUNT_LEVEL_FEATURE_DEFAULTS` |
| Daily job doesn't reset plan | `custom/` overlay (code) |

---

## How to Edit Installation Configs from UI

1. Go to Super Admin → left sidebar → **Installation Configs**
2. Find the config by name
3. Click **Edit**
4. Change the value
5. Save

No server restart needed — changes take effect immediately (after cache clear).
