module RedmineAnonymousWatchers
  module MailerExtension
    #unloadable

    

    def deliver_issue_edit(journal)

      if (journal && !journal.private_notes?)
        recipients = journal.issue.watcher_mails
        recipients.select! do |user|
          journal.notes? || journal.visible_details(user).any?
        end
        recipients.each do |user|
          puts user
          unless user.is_a?(User)
            mail = user
            user = User.new
            names = mail.gsub(/@.*$/, '').split('.')
            user.login = mail
            user.firstname = names
            user.lastname = '-'
            user.language = Setting.default_language
            user.generate_password = true
            user.mail_notification = 'only_my_events'
            user.mail = mail
            user.save!
          end

          issue_edit(user, journal).deliver_later
        end
      end

      super
    end

    
  end
end

