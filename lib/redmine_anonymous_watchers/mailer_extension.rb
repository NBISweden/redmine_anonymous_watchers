module RedmineAnonymousWatchers
  module MailerExtension
    #unloadable

    def deliver_issue_edit(journal)
      (1..20).each do puts "new extension" end

      if (journal && !journal.private_notes?)
        recipients = journal.issue.watcher_mails
        recipients.select! do |user|
          journal.notes? || journal.visible_details(user).any?
        end
        recipients.each do |user|
          (1..20).each do puts "Send Mail" end
          puts user
          # The issue_edit wants a User object, this was one way I tried to create one that didn't succeed all the way.
          #u = User.new
          ##u.name = user
          #u.mail = user
          #u.id = 0xdeadbeef
          issue_edit(user, journal).deliver_later
        end
      end

      super
    end
  end
end

