class IntakeAttachment < ApplicationRecord
  belongs_to :intake_session
  belongs_to :intake_message, optional: true

  has_many :source_field_values, class_name: "IntakeFieldValue", foreign_key: :source_attachment_id, inverse_of: :source_attachment, dependent: :nullify

  validates :mime_type, :file_name, :processing_status, presence: true
end
