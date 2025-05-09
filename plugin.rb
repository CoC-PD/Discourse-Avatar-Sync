# name: discourse-avatar-sync
# about: Syncs avatar from SingleSignOnRecord on login, or uses default if not provided
# version: 0.3
# authors: Tasveer Dhillon
# url: https://github.com/CoC-PD/Discourse-Avatar-Sync

begin
  Rails.logger.warn("[AvatarSync] Plugin file loaded successfully")
rescue => e
  puts "[AvatarSync] Failed to log plugin load: #{e.message}"
end

after_initialize do
  begin
    Rails.logger.warn("[AvatarSync] after_initialize hook fired")

    DiscourseEvent.on(:user_logged_in) do |user|
      Rails.logger.warn("[AvatarSync] user_logged_in event for #{user.username}")

      begin
        sso_record = SingleSignOnRecord.find_by(user_id: user.id)

        if sso_record&.external_avatar_url.present?
          Jobs.enqueue(:download_avatar_from_url, {
            user_id: user.id,
            url: sso_record.external_avatar_url,
            override_gravatar: true
          })
          Rails.logger.warn("[AvatarSync] Avatar updated from SSO for #{user.username}")
        else
          # Clear custom avatar and use default fallback
          user.user_avatar&.custom_upload&.destroy
          user.update(uploaded_avatar_id: nil)
          Jobs.enqueue(:generate_avatars, user_id: user.id)
          Rails.logger.warn("[AvatarSync] No external avatar, reverted to default for #{user.username}")
        end
      rescue => e
        Rails.logger.error("[AvatarSync] Error syncing avatar for #{user.username}: #{e.message}")
      end
    end

  rescue => e
    Rails.logger.error("[AvatarSync] Error in after_initialize block: #{e.message}")
  end
end
