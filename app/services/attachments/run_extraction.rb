module Attachments
  class RunExtraction
    def self.call(attachment_id:)
      new(attachment_id: attachment_id).call
    end

    def initialize(attachment_id:)
      @attachment_id = attachment_id
    end

    def call
      # TODO: Dispatch OCR/text extraction for attachment and persist extraction metadata.
      { status: :stubbed, attachment_id: @attachment_id, extracted_text: nil }
    end
  end
end
