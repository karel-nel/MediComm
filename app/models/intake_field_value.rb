class IntakeFieldValue < ApplicationRecord
  belongs_to :intake_session
  belongs_to :intake_field
  belongs_to :source_message, class_name: "IntakeMessage", optional: true, inverse_of: :source_field_values
  belongs_to :source_attachment, class_name: "IntakeAttachment", optional: true, inverse_of: :source_field_values
  belongs_to :verified_by_user, class_name: "User", optional: true, inverse_of: :verified_field_values
  belongs_to :superseded_by, class_name: "IntakeFieldValue", optional: true

  enum :status, {
    missing: 0,
    candidate: 1,
    complete: 2,
    needs_clarification: 3,
    skipped: 4,
    rejected: 5,
    inferred: 6
  }, prefix: true

  validates :confidence, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }
end
