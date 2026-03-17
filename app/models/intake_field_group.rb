class IntakeFieldGroup < ApplicationRecord
  belongs_to :intake_flow
  has_many :intake_fields, dependent: :nullify

  scope :active, -> { where(archived_at: nil) }

  validates :key, :label, presence: true
  validates :key, uniqueness: { scope: :intake_flow_id }
  validates :position, numericality: { greater_than_or_equal_to: 0 }
  validates :repeatable, inclusion: { in: [ true, false ] }

  def archived?
    archived_at.present?
  end
end
