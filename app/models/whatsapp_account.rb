class WhatsappAccount < ApplicationRecord
  belongs_to :practice
  has_many :intake_sessions, dependent: :restrict_with_exception

  scope :active, -> { where(active: true) }
  before_validation :normalize_credentials

  validates :phone_number_id, :waba_id, :display_phone_number, presence: true
  validates :phone_number_id, uniqueness: { scope: :practice_id }
  validates :webhook_verify_token, uniqueness: true, allow_blank: true
  validates :active, inclusion: { in: [ true, false ] }
  validates :webhook_verify_token, :app_secret_ciphertext, presence: true, if: :active?

  private

  def normalize_credentials
    self.phone_number_id = phone_number_id.to_s.strip.presence
    self.webhook_verify_token = webhook_verify_token.to_s.strip.presence
    self.app_secret_ciphertext = app_secret_ciphertext.to_s.strip.presence
    self.access_token_ciphertext = access_token_ciphertext.to_s.strip.presence
  end
end
