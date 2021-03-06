# frozen_string_literal: true

module Thredded
  class UserMessageboardPreference < ActiveRecord::Base
    belongs_to :user_preference,
               primary_key: :user_id,
               foreign_key: :user_id,
               inverse_of: :messageboard_preferences
    belongs_to :user,
               class_name: Thredded.user_class_name,
               inverse_of: :thredded_user_messageboard_preferences
    belongs_to :messageboard

    validates :user_id, presence: true
    validates :messageboard_id, presence: true

    after_initialize :set_auto_follow_from_user_preference, unless: :persisted?

    scope :auto_followers, -> { where(auto_follow_topics: true) }

    def self.in(messageboard)
      find_or_initialize_by(messageboard_id: messageboard.id)
    end

    def user_preference
      super || build_user_preference
    end

    def user_id=(value)
      super
      set_auto_follow_from_user_preference
    end

    def user=(value)
      super
      set_auto_follow_from_user_preference
    end

    private

    def set_auto_follow_from_user_preference
      self.auto_follow_topics = user_preference.auto_follow_topics if user_id && !id
    end
  end
end
