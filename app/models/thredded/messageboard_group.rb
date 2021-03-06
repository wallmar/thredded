# frozen_string_literal: true

module Thredded
  class MessageboardGroup < ActiveRecord::Base
    has_many :messageboards,
             -> { ordered_by_position },
             inverse_of: :group,
             foreign_key: :messageboard_group_id,
             dependent: :nullify

    scope :ordered, -> { order(position: :asc, id: :asc) }
    validates :name,
              presence: true,
              uniqueness: { case_sensitive: false }
    validates :position, presence: true, on: :update
    before_save :ensure_position

    def ensure_position
      self.position ||= Time.zone.now.to_i
    end

    def self.find!(slug_or_id)
      find(slug_or_id)
    rescue ActiveRecord::RecordNotFound
      raise Thredded::Errors::MessageboardGroupNotFound
    end
  end
end
