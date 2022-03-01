

module RedmineAnonymousWatchers
  module WatchersControllerPatch
    unloadable

    def self.included(base)
      base.send(:include, InstanceMethods)
      base.class_eval do
        alias_method :destroy_without_anonymous, :destroy
        alias_method :destroy, :destroy_with_anonymous
        alias_method :create_without_anonymous, :create
        alias_method :create, :create_with_anonymous
        alias_method :append_without_anonymous, :append
        alias_method :append, :append_with_anonymous

        before_action :check_project_privacy, :only => [:anonymous_watch, :anonymous_unwatch]
        before_action :authorize_global, :only => [:anonymous_watch, :anonymous_unwatch]
      end
    end

    module InstanceMethods
      def anonymous_watch
        if @watched.respond_to?(:visible?) && !@watched.visible?(User.current)
          render_403
        else
          watcher = AnonymousWatcher.new(:mail => params[:mail], :anonymous_token => anonymous_token)
          if !watcher.valid?
            respond_to do |format|
              format.html { flash[:error] = l(:text_cannot_add_watcher); redirect_to_referer_or {render_error :text_cannot_add_watcher} }
              format.js { render :partial => 'anonymous_error', :locals => {:text => l(:text_cannot_add_watcher), :prompt => true} }
            end
          elsif @watched.watched_by?(params[:mail]) && !@watched.watched_by?(watcher)
            respond_to do |format|
              format.html { flash[:error] = l(:text_already_subscribed); redirect_to_referer_or {render_error :text_already_subscribed} }
              format.js { render :partial => 'anonymous_error', :locals => {:text => l(:text_already_subscribed), :prompt => false} }
            end
          else
            cookies[:watcher_mail] = params[:mail]
            set_watcher(watcher, true)
          end
        end
      end

      def anonymous_unwatch
        set_watcher(AnonymousWatcher.new(:anonymous_token => anonymous_token), false) if anonymous_token
      end

      def destroy_with_anonymous
        if params[:mail]
          @watchables.each do |watchable|
	    watchable.set_watcher(params[:mail], false) if request.delete?
        end
          respond_to do |format|
            format.html { redirect_to :back }
            format.js
          end
        else
          destroy_without_anonymous
        end
      end

      def append_with_anonymous
        if params[:watcher].key?(:mails)
          @watcher_mails = params[:watcher][:mails].split(/[\s,]+/) || [params[:watcher][:mail]]
        end
        if params[:watcher]
          user_ids = params[:watcher][:user_ids] || [params[:watcher][:user_id]]
          @users = Principal.assignable_watchers.where(:id => user_ids).to_a
        end
      end

      def create_with_anonymous
        watcher = params[:watcher]
        if watcher.key?(:mails) && request.post?
          mails = watcher[:mails].split(/[\s,]+/) || [watcher[:mail]]
          user_ids = []
          mails.each do |mail|
            u = User.find_by_mail(mail)
            if !u || (u.is_a?(User) && u.groups.any? { |group| group.name == 'Anonymous Watchers' })
              @watchables.each do |watchable|
                AnonymousWatcher.create(:watchable => watchable, :mail => mail) if mail.present?
              end
            else
              user_ids << u.id
            end
          end
        end
        params[:watcher][:user_ids] = user_ids unless (user_ids.nil? || user_ids.empty?)
        create_without_anonymous
      end

    end
  end
end
