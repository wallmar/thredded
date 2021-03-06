# frozen_string_literal: true

module Thredded
  class TopicsController < Thredded::ApplicationController # rubocop:disable Metrics/ClassLength
    include Thredded::NewTopicParams
    include Thredded::NewPostParams

    before_action :thredded_require_login!,
                  only: %i[update create destroy follow unfollow unread mark_as_read mark_all_as_read]

    before_action :verify_messageboard,
                  only: %i[index search unread]

    before_action :use_topic_messageboard,
                  only: %i[show update destroy follow unfollow increment mark_as_read]

    after_action :update_user_activity

    after_action :verify_authorized, except: %i[show search unread mark_all_as_read]
    after_action :verify_policy_scoped, except: %i[show create update destroy unfollow increment mark_as_read mark_all_as_read]

    def index
      page_scope = policy_scope(messageboard.topics)
        .order_sticky_first.order_recently_posted_first
        .includes(:categories, :last_user, :user)
        .send(Kaminari.config.page_method_name, current_page)
      @topics_page_view = Thredded::TopicsPageView.new(thredded_current_user, page_scope)
      render json: TopicViewSerializer.new(@topics_page_view.topic_views,
                                           include: %i[topic categories read_state follow topic.user topic.last_user topic.messageboard])
        .serializable_hash.to_json, status: 200
    end

    def unread
      page_scope = topics_scope
        .unread(thredded_current_user)
        .order_followed_first(thredded_current_user).order_recently_posted_first
        .includes(:categories, :last_user, :user)
        .send(Kaminari.config.page_method_name, current_page)
      return redirect_to(last_page_params(page_scope)) if page_beyond_last?(page_scope)
      @topics = Thredded::TopicsPageView.new(thredded_current_user, page_scope)
      render json: TopicViewSerializer.new(@topics.topic_views, include: %i[topic follow topic.user topic.last_user]).serializable_hash.to_json, status: 200
    end

    def search
      @query = params[:q].to_s
      page_scope = topics_scope
        .search_query(@query)
        .order_recently_posted_first
        .includes(:categories, :last_user, :user)
        .send(Kaminari.config.page_method_name, current_page)
      @topics = Thredded::TopicsPageView.new(thredded_current_user, page_scope)
      render json: TopicViewSerializer.new(@topics.topic_views,
                                           include: %i[topic read_state follow topic.user topic.last_user])
        .serializable_hash.to_json, status: 200
    end

    def show
      page_scope = policy_scope(topic.posts)
        .order_oldest_first
        .includes(:user, :messageboard)
        .send(Kaminari.config.page_method_name, current_page)
      @posts = Thredded::TopicPostsPageView.new(thredded_current_user, topic, page_scope)
      render json: TopicPostsPageViewSerializer.new(@posts,
                                                    include: %i[post_views topic post_views.post topic.topic topic.categories
                                                                post_views.post.user post_views.post.user.thredded_user_detail])
        .serializable_hash.to_json, status: 200
    end

    def create
      @new_topic = Thredded::TopicForm.new(new_topic_params)
      begin
        authorize_creating @new_topic.topic
      rescue ActiveRecord::SubclassNotFound
        raise Thredded::Errors::TopicSubclassNotFound
      rescue ActiveRecord::RecordNotFound
        raise Thredded::Errors::CategoryNotFound
      end
      if @new_topic.save
        render json: TopicSerializer.new(@new_topic.topic, include: %i[user last_user categories]).serializable_hash.to_json, status: 201
      else
        render json: { errors: @new_topic.errors }, status: 422
      end
    end

    def update
      topic.assign_attributes(topic_params_for_update)
      authorize topic, :update?
      if topic.messageboard_id_changed?
        # Work around the association not being reset.
        # TODO: report issue to Rails. Looks like a regression of:
        # https://rails.lighthouseapp.com/projects/8994/tickets/2989
        topic.messageboard = Thredded::Messageboard.find(topic.messageboard_id)

        authorize topic.messageboard, :post?
      end
      @edit_topic = Thredded::EditTopicForm.new(user: thredded_current_user, topic: topic)
      if @edit_topic.save
        render json: TopicSerializer.new(@edit_topic.topic, include: %i[user last_user categories]).serializable_hash.to_json, status: 200
      else
        render json: { errors: @edit_topic.errors }, status: 422
      end
    end

    def destroy
      authorize topic, :destroy?
      topic.destroy!
      head 204
    end

    def follow
      authorize topic, :read?
      Thredded::UserTopicFollow.create_unless_exists(thredded_current_user.id, topic.id)
      render_topic_view(topic)
    end

    def unfollow
      authorize topic, :read?
      Thredded::UserTopicFollow.find_by(topic_id: topic.id, user_id: thredded_current_user.id).try(:destroy)
      render_topic_view(topic)
    end

    def increment
      authorize topic, :read?
      topic.increment!(:view_count)
      head 204
    end

    def mark_as_read
      authorize topic, :read?
      Thredded::MarkAllReadTopic.run(thredded_current_user, topic)
      head 204
    end

    def mark_all_as_read
      Thredded::MarkAllReadAllTopics.run(thredded_current_user, messageboard_or_nil)
      head 204
    end

    private

    def next_page_after_create(next_page)
      case next_page
      when 'messageboard', '', nil
        return messageboard_topics_path(messageboard)
      when 'topic'
        messageboard_topic_path(messageboard, @new_topic.topic)
      when %r{\A/[^/]\S+\z}
        next_page
      else
        fail "Unexpected value for next page: #{next_page.inspect}"
      end
    end

    def in_messageboard?
      params.key?(:messageboard_id)
    end

    def init_new_topic
      return unless in_messageboard?
      form = Thredded::TopicForm.new(messageboard: messageboard, user: thredded_current_user)
      form if policy(form.topic).create?
    end

    def render_topic_view(topic)
      page_scope = topics_scope.where(id: topic.id)
      topics = Thredded::TopicsPageView.new(thredded_current_user, page_scope)
      render json: TopicViewSerializer.new(topics.topic_views,
                                           include: %i[topic read_state follow topic.user topic.last_user])
        .serializable_hash.to_json, status: 200
    end

    def verify_messageboard
      return unless in_messageboard?
      authorize_reading messageboard
      return if params_match?(canonical_messageboard_params)
      skip_policy_scope
      redirect_to(canonical_messageboard_params.merge(q: params[:q]))
    end

    def canonical_messageboard_params
      { messageboard_id: messageboard.slug }
    end

    def canonical_topic_params
      { messageboard_id: messageboard.slug, id: topic.slug }
    end

    # Returns the `@topic` instance variable.
    # If `@topic` is not set, it first sets it to the topic with the slug or ID given by `params[:id]`.
    #
    # @return [Thredded::Topic]
    # @raise [Thredded::Errors::TopicNotFound] if the topic with the given slug does not exist.
    def topic
      @topic ||= Thredded::Topic.friendly_find!(params[:id])
    end

    # Use the topic's messageboard instead of the one specified in the URL,
    # to account for `params[:messageboard_id]` pointing to the wrong messageboard
    def use_topic_messageboard
      @messageboard = topic.messageboard
    end

    def topic_params
      new_topic_params
    end

    def topic_params_for_update
      params
        .require(:topic)
        .permit(:title, :locked, :sticky, category_ids: [])
    end

    def current_page
      (params[:page] || 1).to_i
    end
  end
end
