# frozen_string_literal: true

module Thredded
  # Marks all private topics as read for the given user.
  class MarkAllReadAllTopics
    def self.run(user, messageboard)
      Thredded::Topic.unread(user, messageboard).each do |topic|
        Thredded::MarkAllReadTopic.run(user, topic)
      end
    end
  end
end
