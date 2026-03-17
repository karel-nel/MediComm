class ExportedDocument < ApplicationRecord
  belongs_to :intake_session

  validates :document_type, :status, presence: true
end
