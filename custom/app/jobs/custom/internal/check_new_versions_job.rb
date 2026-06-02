# frozen_string_literal: true

module Custom::Internal::CheckNewVersionsJob
  def perform
    # Skip plan enforcement from hub.
    # Still check for version updates (harmless).
    @instance_info = ChatwootHub.sync_with_hub
    update_version_info
  end
end
