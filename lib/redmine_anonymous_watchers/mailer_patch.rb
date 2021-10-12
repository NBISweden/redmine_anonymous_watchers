module RedmineAnonymousWatchers
  module MailerPatch
    unloadable

    def self.included(base)
      base.send(:include, InstanceMethods)
      base.class_eval do
        alias_method :issue_add_without_anonymous_watchers, :issue_add
        alias_method :issue_add, :issue_add_with_anonymous_watchers
        alias_method :issue_edit_without_anonymous_watchers, :issue_edit
        alias_method :issue_edit, :issue_edit_with_anonymous_watchers

        alias_method :document_added_without_anonymous_watchers, :document_added
        alias_method :document_added, :document_added_with_anonymous_watchers
        alias_method :attachments_added_without_anonymous_watchers, :attachments_added
        alias_method :attachments_added, :attachments_added_with_anonymous_watchers
        alias_method :news_added_without_anonymous_watchers, :news_added
        alias_method :news_added, :news_added_with_anonymous_watchers
        if Redmine::VERSION::MAJOR < 2
          alias_method :create_mail_without_anonymous_watchers, :create_mail
          alias_method :create_mail, :create_mail_with_anonymous_watchers
        else
          alias_method :mail_without_anonymous_watchers, :mail
          alias_method :mail, :mail_with_anonymous_watchers
        end
      end
    end

    module InstanceMethods
      def issue_add_with_anonymous_watchers(user, issue)
        users = issue.notified_users | issue.notified_watchers

        if(@journal)
          @subscription_recipients = @journal.issue.watcher_mails
        else
          @subscription_recipients = (users).collect{|u| u.mail } | issue.watcher_mails
        end

        issue_add_without_anonymous_watchers(user, issue)
      end

      def issue_edit_with_anonymous_watchers(user, journal)
        # do not include anonymous watchers when private notes added
        if(journal && !journal.private_notes?)
          issue = journal.journalized
          @subscription_recipients = journal.issue.watcher_mails
          @subscription_recipients.select! do |user|
            journal.notes? || journal.visible_details(user).any?
          end
        end
        # use public link if applicable
        @public_url = nil
        if (issue && issue.project.module_enabled?(:semipublic_links))
          pl = PublicLink.find_by({:issue_id => issue.id})
          # only if pl exist and is active:
          if(pl && pl.active)
            @public_url = url_for(action: 'resolve', controller: 'public_links', url: pl.url)
          end
        end

        issue_edit_without_anonymous_watchers(user, journal)
      end

      def document_added_with_anonymous_watchers(document)
        @subscription_recipients = document.project.documents_recipients
        document_added_without_anonymous_watchers(document)
      end

      def attachments_added_with_anonymous_watchers(attachments)
        container = attachments.first.container
        case container.class.name
        when 'Project'
          @subscription_recipients = container.files_recipients
        when 'Version'
          @subscription_recipients = container.project.files_recipients
        when 'Document'
          @subscription_recipients = container.project.documents_recipients
        end
        attachments_added_without_anonymous_watchers(attachments)
      end

      def news_added_with_anonymous_watchers(news)
        @subscription_recipients = news.project.news_recipients
        news_added_without_anonymous_watchers(news)
      end

      def mail_with_anonymous_watchers(headers={}, &block)
        headers[:cc] = (Array(headers[:cc]) + Array(@subscription_recipients) - Array(headers[:to])).uniq
        @issue_url = @public_url if @public_url
        mail_without_anonymous_watchers(headers, &block)
      end

      def create_mail_with_anonymous_watchers
        cc (Array(cc) + Array(@subscription_recipients) - Array(recipients)).uniq
        create_mail_without_anonymous_watchers
      end
    end
  end
end

