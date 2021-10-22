module RedmineAnonymousWatchers
  module MailerPatch
    unloadable

    def self.included(base)
      base.send(:include, InstanceMethods)
      base.class_eval do
        alias_method :issue_edit_without_anonymous_watchers, :issue_edit
        alias_method :issue_edit, :issue_edit_with_anonymous_watchers

        alias_method :mail_without_anonymous_watchers, :mail
        alias_method :mail, :mail_with_anonymous_watchers
      end
    end

    module InstanceMethods
      def issue_edit_with_anonymous_watchers(user, journal)
        
        if(journal && !journal.private_notes?)
          issue = journal.journalized
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

      def mail_with_anonymous_watchers(headers={}, &block)
        @issue_url = @public_url if @public_url
        mail_without_anonymous_watchers(headers, &block)
      end
    end
  end
end
