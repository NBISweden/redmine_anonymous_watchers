module RedmineAnonymousWatchers
  module MailerExtension
    #unloadable

    def create_user(mail)
      user = User.new
      names = mail.gsub(/@.*$/, '')
      puts names
      puts names.class
      names_list = names.include?(".") ? names.split('.') : [names, '-']
      user.login = mail
      user.firstname = names_list[0]
      user.lastname = names_list[1]
      user.language = Setting.default_language
      user.generate_password = true
      user.mail_notification = 'only_my_events'
      user.mail = mail
      user.save!
      user.lock!
      user
    end
    
    def deliver_issue_add(issue)
      users = issue.watcher_mails
      users.each do |user|
        unless user.is_a?(User)
          mail = user
          user = User.find_by_mail(mail)
          user = create_user(mail) unless user
        end
        issue_add(user, issue).deliver_later
      end      
    end
            

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
            user = User.find_by_mail(mail)
            user = create_user(mail) unless user
          end
          issue_edit(user, journal).deliver_later
        end
      end
    end

  end
end

