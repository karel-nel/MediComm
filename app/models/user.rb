class User < ApplicationRecord
  attr_accessor :practice_name

  belongs_to :practice
  has_many :created_intake_flows, class_name: "IntakeFlow", foreign_key: :created_by_id, inverse_of: :created_by
  has_many :initiated_intake_sessions, class_name: "IntakeSession", foreign_key: :initiated_by_user_id, inverse_of: :initiated_by_user
  has_many :session_reviews, foreign_key: :reviewer_id, inverse_of: :reviewer
  has_many :verified_field_values, class_name: "IntakeFieldValue", foreign_key: :verified_by_user_id, inverse_of: :verified_by_user

  enum :role, { owner: 0, admin: 1, staff: 2, read_only: 3 }, prefix: true

  validates :first_name, :last_name, :practice, presence: true
  validates :active, inclusion: { in: [ true, false ] }

  before_validation :normalize_email

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  def full_name
    "#{first_name} #{last_name}".strip
  end

  private

  def normalize_email
    self.email = email.to_s.downcase.strip
  end
end
