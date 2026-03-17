class SessionReview < ApplicationRecord
  belongs_to :intake_session
  belongs_to :reviewer, class_name: "User", inverse_of: :session_reviews

  enum :status, { pending: 0, approved: 1, needs_follow_up: 2 }, prefix: true

  validates :status, presence: true
end
