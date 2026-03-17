class IntakeSession < ApplicationRecord
  belongs_to :practice
  belongs_to :intake_flow
  belongs_to :whatsapp_account
  belongs_to :initiated_by_user, class_name: "User", inverse_of: :initiated_intake_sessions

  has_many :intake_messages, -> { order(:created_at) }, dependent: :destroy
  has_many :intake_attachments, -> { order(:created_at) }, dependent: :destroy
  has_many :intake_field_values, -> { order(:created_at) }, dependent: :destroy
  has_many :intake_events, -> { order(created_at: :desc) }, dependent: :destroy
  has_one :session_review, dependent: :destroy
  has_many :exported_documents, dependent: :destroy

  enum :status, {
    pending_start: 0,
    active: 1,
    awaiting_patient: 2,
    processing: 3,
    awaiting_staff_review: 4,
    completed: 5,
    abandoned: 6,
    failed: 7
  }, prefix: true

  validates :patient_phone_e164, :patient_display_name, :language, presence: true
end
