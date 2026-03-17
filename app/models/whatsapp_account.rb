class WhatsappAccount < ApplicationRecord
  belongs_to :practice
  has_many :intake_sessions, dependent: :restrict_with_exception

  scope :active, -> { where(active: true) }

  validates :phone_number_id, :waba_id, :display_phone_number, presence: true
  validates :phone_number_id, uniqueness: { scope: :practice_id }
  validates :active, inclusion: { in: [ true, false ] }
end
