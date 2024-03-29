module RedmineAnonymousWatchers
  module MailerExtension

    def find_or_create_user(mail)
      user = User.find_by_mail(mail)
      user = create_user(mail) unless user
      user
    end

    def find_or_create_group()
      group = Group.find_by(:lastname => "Anonymous Watchers")
      if ! group
        group = Group.new()
        group.name = "Anonymous Watchers"
      end
      group
    end

    def create_user(mail)
      names = mail.gsub(/@.*$/, '')
      names_list = names.include?(".") ? names.split('.') : [names, '-']

      user = User.new
      user.login = mail
      user.firstname = names_list[0]
      user.lastname = names_list[1]
      user.language = Setting.default_language
      user.generate_password = true
      user.mail_notification = 'none'
      user.mail = mail

      group = find_or_create_group()
      group.users << user
      group.save!
      user.lock!
      user.save!
      user
    end

    def deliver_issue_add(issue)
      users = issue.watcher_mails
      users.each do |user|
        unless user.is_a?(User)
          user = find_or_create_user(user)
        end
        issue_add(user, issue).deliver_later
      end

      super
    end


    def deliver_issue_edit(journal)
      if (journal && !journal.private_notes?)
        recipients = journal.issue.watcher_mails
        recipients.select! do |user|
          journal.notes? || journal.visible_details(user).any?
        end
        recipients.each do |user|
          unless user.is_a?(User)
            user = find_or_create_user(user)
          end
          issue_edit(user, journal).deliver_later
        end
      end

      super
    end

  end
end
