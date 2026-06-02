# frozen_string_literal: true

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
    end

    defaults = premium_features.map { |f| { 'name' => f, 'enabled' => true } }
    InstallationConfig.find_or_create_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS').update!(value: defaults)

    GlobalConfig.clear_cache
    puts '[enterprise_setup] Done! Plan: enterprise, all features enabled.'
  end
end
