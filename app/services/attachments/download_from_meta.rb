module Attachments
  class DownloadFromMeta
    def self.call(attachment_id:)
      new(attachment_id: attachment_id).call
    end

    def initialize(attachment_id:)
      @attachment_id = attachment_id
    end

    def call
      # TODO: Download media bytes from Meta media API.
      { status: :stubbed, attachment_id: @attachment_id, temp_path: nil }
    end
  end
end
