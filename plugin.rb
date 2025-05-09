# name: discourse-avatar-sync
# about: Syncs avatar from SingleSignOnRecord on login, or uses default if not provided
# version: 1.0
# authors: Tasveer Dhillon
# url: https://github.com/<your-github-username>/discourse-avatar-sync

after_initialize do
  Rails.logger.warn("[AvatarSync] Plugin initialized and after_initialize hook fired")

  DiscourseEvent.on(:user_logged_in) do |user|
    Rails.logger.warn("[AvatarSync] user_logged_in event for #{user.username}")

    begin
      sso_record = SingleSignOnRecord.find_by(user_id: user.id)

      if sso_record&.external_avatar_url.present?
        UserAvatar.import_url_for_user(sso_record.external_avatar_url, user)
        Rails.logger.warn("[AvatarSync] Avatar imported from URL for #{user.username}")
      else
        user.user_avatar&.custom_upload&.destroy
        user.update(uploaded_avatar_id: nil)
        Jobs.enqueue(:generate_avatars, user_id: user.id)
        Rails.logger.warn("[AvatarSync] No external avatar; reverted to default for #{user.username}")
      end
    rescue => e
      Rails.logger.error("[AvatarSync] Error syncing avatar for #{user.username}: #{e.message}")
    end
  end
end
