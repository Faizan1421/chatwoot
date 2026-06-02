# Enterprise Seed Commands

Run these commands **once** after the first deployment (after `db:schema:load` or `db:migrate` + `db:seed`).

## One-Time Setup (Rails Console)

```bash
bundle exec rails console
```

Paste all of this:

```ruby
# 1. Set installation to enterprise plan
InstallationConfig.find_or_create_by(name: 'INSTALLATION_PRICING_PLAN').update!(value: 'enterprise')
InstallationConfig.find_or_create_by(name: 'DEPLOYMENT_ENV').update!(value: 'self-hosted')
InstallationConfig.find_or_create_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY').update!(value: 100000)

# 2. Enable all premium features on all accounts
premium_features = %w[
  sla audit_logs custom_roles disable_branding
  captain_integration captain_integration_v2 custom_tools
  csat_review_notes conversation_required_attributes
  channel_voice saml companies advanced_assignment
  captain_document_auto_sync advanced_search
  help_center_embedding_search captain_tasks
]

Account.find_each do |a|
  a.enable_features!(*premium_features)
  attrs = a.custom_attributes || {}
  attrs['subscribed_quantity'] = 100000
  a.update!(custom_attributes: attrs)
end

# 3. Set defaults for any NEW accounts created in the future
defaults = premium_features.map { |f| { 'name' => f, 'enabled' => true } }
InstallationConfig.find_or_create_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS').update!(value: defaults)

# 4. Clear cache
GlobalConfig.clear_cache

# 5. Verify
puts "Plan: #{ChatwootHub.pricing_plan}"
puts "Plan Quantity: #{ChatwootHub.pricing_plan_quantity}"
puts "Enterprise: #{ChatwootApp.enterprise?}"
puts "Custom: #{ChatwootApp.custom?}"
puts "Accounts: #{Account.count}"
puts "Done!"
```

Expected output:

```
Plan: enterprise
Plan Quantity: 100000
Enterprise: true
Custom: true
Accounts: X
Done!
```

---

## What each command does

| Command | Purpose |
|---------|---------|
| `INSTALLATION_PRICING_PLAN = enterprise` | Tells the app it's running enterprise edition |
| `DEPLOYMENT_ENV = self-hosted` | Prevents cloud-only behaviors |
| `INSTALLATION_PRICING_PLAN_QUANTITY = 100000` | Removes "add more licenses" banner in Super Admin |
| `enable_features!(...)` | Unlocks all premium features on existing accounts |
| `subscribed_quantity = 100000` | Removes per-account agent seat limit warning |
| `ACCOUNT_LEVEL_FEATURE_DEFAULTS` | Ensures new accounts get all features automatically |
| `GlobalConfig.clear_cache` | Makes changes take effect immediately |

---

## For Coolify Deployment

After the first deploy, exec into the Rails container:

```bash
# In Coolify → rails service → Terminal
# OR via CLI:
docker exec -it <chatwoot-rails-container> bundle exec rails console
```

Then paste the same commands above.

### Automating it (optional)

To avoid running this manually on every fresh deploy, create a rake task:

```bash
# This file should exist at: lib/tasks/enterprise_setup.rake
```

```ruby
# lib/tasks/enterprise_setup.rake
namespace :chatwoot do
  desc 'One-time enterprise setup for self-hosted deployment'
  task enterprise_setup: :environment do
    InstallationConfig.find_or_create_by(name: 'INSTALLATION_PRICING_PLAN').update!(value: 'enterprise')
    InstallationConfig.find_or_create_by(name: 'DEPLOYMENT_ENV').update!(value: 'self-hosted')
    InstallationConfig.find_or_create_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY').update!(value: 100_000)

    premium_features = %w[
      sla audit_logs custom_roles disable_branding
      captain_integration captain_integration_v2 custom_tools
      csat_review_notes conversation_required_attributes
      channel_voice saml companies advanced_assignment
      captain_document_auto_sync advanced_search
      help_center_embedding_search captain_tasks
    ]

    Account.find_each do |a|
      a.enable_features!(*premium_features)
      attrs = a.custom_attributes || {}
      attrs['subscribed_quantity'] = 100_000
      a.update!(custom_attributes: attrs)
    end

    defaults = premium_features.map { |f| { 'name' => f, 'enabled' => true } }
    InstallationConfig.find_or_create_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS').update!(value: defaults)

    GlobalConfig.clear_cache
    puts '[enterprise_setup] Done! Plan: enterprise, all features enabled.'
  end
end
```

Then run it with:

```bash
bundle exec rails chatwoot:enterprise_setup
```

You can add this to your Coolify post-deploy script or Docker entrypoint so it runs automatically after every deploy.

---

## When to re-run

- After fresh database setup (first deploy)
- After restoring a database backup that doesn't have these configs
- NOT needed after code updates (configs persist in the database)
