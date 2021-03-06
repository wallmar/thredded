# frozen_string_literal: true

module Thredded
  # A controller for managing {PrivatePost}s.
  class PrivatePostsController < Thredded::ApplicationController
    include ActionView::RecordIdentifier
    include NewPrivatePostParams

    helper_method :topic

    before_action :thredded_require_login!, only: %i[update create destroy mark_as_read mark_as_unread]

    after_action :verify_authorized

    def create
      @post_form = Thredded::PrivatePostForm.new(
        user: thredded_current_user, topic: parent_topic, post_params: new_private_post_params
      )
      authorize_creating @post_form.post
      if @post_form.save
        render json: PrivatePostSerializer.new(@post_form.post).serializable_hash.to_json, status: 201
      else
        render json: { errors: @post_form.errors }, status: 422
      end
    end

    # include of postable & user is missing
    def update
      authorize post, :update?
      if post.update(new_private_post_params)
        render json: PrivatePostSerializer.new(post).serializable_hash.to_json, status: 200
      else
        render json: { errors: post.errors }, status: 422
      end
    end

    def destroy
      authorize post, :destroy?
      post.destroy!
      head 204
    end

    def mark_as_read
      authorize post, :read?
      UserPrivateTopicReadState.touch!(thredded_current_user.id, post)
      head 204
    end

    def mark_as_unread
      authorize post, :read?
      post.mark_as_unread(thredded_current_user)
      head 204
    end

    private

    def canonical_topic_params
      { private_topic_id: topic.slug }
    end

    def after_mark_as_unread
      redirect_to private_topics_path
    end

    def topic
      post.postable
    end

    def parent_topic
      Thredded::PrivateTopic
        .includes(:private_users)
        .friendly_find!(params[:private_topic_id])
    end

    def post
      @post ||= Thredded::PrivatePost.find!(params[:id])
    end

    def current_page
      params[:page].nil? ? 1 : params[:page].to_i
    end
  end
end
