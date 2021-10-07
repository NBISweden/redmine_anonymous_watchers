require 'plugins/acts_as_watchable/lib/acts_as_watchable'

module RedmineAnonymousWatchers
  module ActsAsWatchablePatch
    def self.included(base)
      base::ClassMethods.send(:include, ClassMethods)
      base::ClassMethods.module_eval do
        alias_method :acts_as_watchable_without_anonymous, :acts_as_watchable
        alias_method :acts_as_watchable, :acts_as_watchable_with_anonymous
      end

      base::InstanceMethods.send(:include, InstanceMethods)
      base::InstanceMethods.module_eval do
        alias_method :add_watcher_without_anonymous, :add_watcher
        alias_method :add_watcher, :add_watcher_with_anonymous
        alias_method :remove_watcher_without_anonymous, :remove_watcher
        alias_method :remove_watcher, :remove_watcher_with_anonymous
        alias_method :watched_by_without_anonymous?, :watched_by?
        alias_method :watched_by?, :watched_by_with_anonymous?
        alias_method :watcher_recipients_without_anonymous, :watcher_recipients
        alias_method :watcher_recipients, :watcher_recipients_with_anonymous

        def watcher_mails
          anonymous_watchers.map(&:mail).compact
        end

        def watcher_mails=(mails)
          anonymous_watchers.delete_all
          mails = Array(mails).map {|m| m.split(/[\s,]+/)}.flatten.delete_if {|m| m.blank?}
          mails.each {|m| anonymous_watchers << AnonymousWatcher.new(:mail => m)}
        end
      end
    end

    module ClassMethods
      def acts_as_watchable_with_anonymous(options = {})
        return if self.included_modules.include?(Redmine::Acts::Watchable::InstanceMethods)
        acts_as_watchable_without_anonymous(options)
        has_many :anonymous_watchers, :as => :watchable, :dependent => :delete_all
      end
    end

    module InstanceMethods
      def add_watcher_with_anonymous(obj)
        case obj
        when User
          add_watcher_without_anonymous(obj)
        when String
          anonymous_watchers << AnonymousWatcher.new(:mail => obj)
        when AnonymousWatcher
          anonymous_watchers << obj
        end
      end

      def remove_watcher_with_anonymous(obj)
        case obj
        when User
          remove_watcher_without_anonymous(obj)
        when String
          AnonymousWatcher.where(:watchable_type => self.class.name, :watchable_id => self.id, :mail => obj).delete_all
        when AnonymousWatcher
          filter = obj.anonymous_token ? {:anonymous_token => obj.anonymous_token} : {:mail => obj.mail}  
          AnonymousWatcher.where({:watchable_type => self.class.name, :watchable_id => self.id}.merge(filter)).delete_all
        end
      end

      def watched_by_with_anonymous?(obj)
        case obj
        when User
          watched_by_without_anonymous?(obj)
        when String
          watcher_mails.include?(obj)
        when AnonymousWatcher
          anonymous_watchers.any? {|w| obj.anonymous_token ? obj.anonymous_token == w.anonymous_token : obj.mail == w.mail}
        else
          false
        end
      end

      def watcher_recipients_with_anonymous
        recipients = watcher_recipients_without_anonymous
        recipients += watcher_mails
        recipients.uniq
      end
    end
  end
end

Redmine::Acts::Watchable.send :include, RedmineAnonymousWatchers::ActsAsWatchablePatch
