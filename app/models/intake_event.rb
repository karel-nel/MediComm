class IntakeEvent < ApplicationRecord
  belongs_to :intake_session

  validates :event_type, presence: true
  validates :payload_json, presence: true
end
