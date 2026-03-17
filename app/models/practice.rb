class Practice < ApplicationRecord
  DEFAULT_TIMEZONE = "Africa/Johannesburg"
  DEFAULT_STATUS = "active"

  has_many :users, dependent: :restrict_with_exception
  has_many :whatsapp_accounts, dependent: :restrict_with_exception
  has_many :intake_flows, dependent: :restrict_with_exception
  has_many :intake_sessions, dependent: :restrict_with_exception
  has_many :intake_messages, through: :intake_sessions
  has_many :intake_attachments, through: :intake_sessions
  has_many :intake_events, through: :intake_sessions
  has_many :session_reviews, through: :intake_sessions
  has_many :exported_documents, through: :intake_sessions

  validates :name, :slug, :timezone, :contact_email, :status, presence: true
  validates :slug, uniqueness: true
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }

  before_validation :normalize_defaults
  before_validation :assign_slug

  private

  def normalize_defaults
    self.timezone = DEFAULT_TIMEZONE if timezone.blank?
    self.status = DEFAULT_STATUS if status.blank?
    self.contact_email = contact_email.to_s.downcase.strip
  end

  def assign_slug
    return if name.blank?
    return if slug.present?

    base_slug = name.parameterize.presence || "practice"
    candidate = base_slug
    sequence = 2

    while self.class.where.not(id: id).exists?(slug: candidate)
      candidate = "#{base_slug}-#{sequence}"
      sequence += 1
    end

    self.slug = candidate
  end
end
