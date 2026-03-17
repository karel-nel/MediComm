class IntakeMessage < ApplicationRecord
  belongs_to :intake_session
  has_many :intake_attachments, dependent: :nullify
  has_many :source_field_values, class_name: "IntakeFieldValue", foreign_key: :source_message_id, inverse_of: :source_message, dependent: :nullify

  enum :direction, { inbound: 0, outbound: 1 }, prefix: true

  validates :message_type, presence: true
  validates :provider_message_id, uniqueness: true, allow_nil: true
end
