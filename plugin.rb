# name: discourse-avatar-sync
# about: Syncs avatar from SingleSignOnRecord on login, or uses default if empty
# version: 0.2
# authors: Tasveer Dhillon

after_initialize do
  DiscourseEvent.on(:user_logged_in) do |user|
    begin
      sso_record = SingleSignOnRecord.find_by(user_id: user.id)

      if sso_record
        avatar_url = sso_record.external_avatar_url

        if avatar_url.present?
          Jobs.enqueue(:download_avatar_from_url, {
            user_id: user.id,
            url: avatar_url,
            override_gravatar: true
          })
          Rails.logger.info("[AvatarSync] Enqueued avatar update for user #{user.username} from SSO")
        else
          # Force Discourse to fall back to default avatar by clearing uploaded avatar
          user.user_avatar&.custom_upload&.destroy
          user.update(uploaded_avatar_id: nil)
          Jobs.enqueue(:generate_avatars, user_id: user.id)
          Rails.logger.info("[AvatarSync] No external avatar; reverted to default for #{user.username}")
        end
      end
    rescue => e
      Rails.logger.warn("[AvatarSync] Failed avatar sync for #{user.username}: #{e.message}")
    end
  end
end
