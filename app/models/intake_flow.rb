class IntakeFlow < ApplicationRecord
  TONE_PRESETS = %w[professional empathetic concise friendly].freeze
  FLOW_TYPES = %w[new_patient follow_up emergency_intake custom].freeze

  belongs_to :practice
  belongs_to :created_by, class_name: "User", inverse_of: :created_intake_flows

  has_many :intake_field_groups, -> { order(:position) }, dependent: :destroy
  has_many :intake_fields, -> { order(:ask_priority) }, dependent: :destroy
  has_many :intake_sessions, dependent: :restrict_with_exception
  accepts_nested_attributes_for :intake_fields, update_only: false

  enum :status, { draft: 0, published: 1, archived: 2 }, prefix: true

  validates :name, :flow_type, :default_language, :tone_preset, presence: true
  validates :flow_type, inclusion: { in: FLOW_TYPES }
  validates :tone_preset, inclusion: { in: TONE_PRESETS }
  validates :name, uniqueness: { scope: :practice_id }
  validates :completion_email_recipients_json, presence: true, if: :completion_email_enabled?
end
