# frozen_string_literal: true

class MessageboardSerializer
  include JSONAPI::Serializer
  attributes :name, :description, :slug, :topics_count, :posts_count, :position, :locked, :created_at, :updated_at
  belongs_to :messageboard_group, serializer: MessageboardGroupSerializer
  belongs_to :last_user, serializer: UserSerializer, record_type: :user
  belongs_to :last_topic, serializer: TopicSerializer, record_type: :topic
end