class IntakeField < ApplicationRecord
  FIELD_TYPES = %w[text long_text date datetime phone email number boolean file select].freeze
  SOURCE_PREFERENCES = %w[any text attachment ocr].freeze

  belongs_to :intake_flow
  belongs_to :intake_field_group, optional: true

  has_many :intake_field_values, dependent: :restrict_with_exception
  scope :active, -> { where(active: true) }

  validates :key, :label, :field_type, :source_preference, presence: true
  validates :key, uniqueness: { scope: :intake_flow_id }
  validates :field_type, inclusion: { in: FIELD_TYPES }
  validates :source_preference, inclusion: { in: SOURCE_PREFERENCES }
  validates :required, :extraction_enabled, :active, inclusion: { in: [ true, false ] }
  validates :ask_priority, numericality: { greater_than_or_equal_to: 0 }
end
