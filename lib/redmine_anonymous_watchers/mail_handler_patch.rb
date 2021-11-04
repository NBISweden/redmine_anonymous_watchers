module RedmineAnonymousWatchers
  module MailHandlerPatch
    unloadable

    def self.included(base)
      base.send(:include, InstanceMethods)
      base.class_eval do
        alias_method :add_watchers_without_anonymous, :add_watchers
        alias_method :add_watchers, :add_watchers_with_anonymous

        alias_method :receive_without_anonymous, :receive
        alias_method :receive, :receive_with_anonymous
      end
    end

    module InstanceMethods
      def receive_with_anonymous(email, options={})
        # The only check we do here is whether it's an anonymous watcher, and
        # if so we temporarily activate the user for the duration of the recieve
        # code.
        #
        # We have to use the mutating! versions that update the database since
        # the original receive code will fetch it again.

        deactivate_user = false
        sender_email = email.from.to_a.first.to_s.strip
        user = User.find_by_mail(sender_email) if sender_email.present?
        if user && !user.active?
          if user.groups.any? { |group| group.name == 'Anonymous Watchers' }
            user.activate!
            deactivate_user = true
          end
        end

        self.receive_without_anonymous(email, options=options)

        if deactivate_user
          user.lock!
        end
      end

      def add_watchers_with_anonymous(obj)
        add_watchers_without_anonymous(obj)
        if handler_options[:no_permission_check] || user.allowed_to?("add_#{obj.class.name.underscore}_watchers".to_sym, obj.project)
          addresses = [email.to, email.cc].flatten.compact.uniq.collect {|a| a.strip.to_s.downcase}
          addresses -= Setting.plugin_redmine_anonymous_watchers[:ignore_emails].to_s.downcase.split(/[\s,]+/)
          addresses -= [redmine_emission_address.to_s.downcase]
          addresses -= obj.watcher_users.map(&:mail)
          # do not add addresses connected to a user account, or existing watchers
          addresses.delete_if{|a| User.find_by_mail(a) || obj.watcher_mails.include?(a)}
          obj.watcher_mails += addresses
        end
      end

      def redmine_emission_address
        obj = if Redmine::VERSION::MAJOR >= 2
          Mail::Address.new(Setting.mail_from)
        else
          TMail::Address.parse(Setting.mail_from)
        end
        obj.address
      end
    end
  end
end

