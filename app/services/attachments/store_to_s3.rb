module Attachments
  class StoreToS3
    def self.call(attachment_id:, source_path: nil)
      new(attachment_id: attachment_id, source_path: source_path).call
    end

    def initialize(attachment_id:, source_path: nil)
      @attachment_id = attachment_id
      @source_path = source_path
    end

    def call
      # TODO: Upload attachment bytes to S3 and persist durable storage key.
      { status: :stubbed, attachment_id: @attachment_id, s3_key: nil }
    end
  end
end
