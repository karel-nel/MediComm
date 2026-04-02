module Attachments
  class RunExtraction
    MAX_EXTRACTED_TEXT_LENGTH = 20_000

    def self.call(attachment_id:)
      new(attachment_id: attachment_id).call
    end

    def initialize(attachment_id:)
      @attachment_id = attachment_id
    end

    def call
      attachment = IntakeAttachment.find(@attachment_id)
      return failure("missing_storage_key", attachment.id) if attachment.s3_key.blank?

      storage_path = resolve_storage_path(attachment.s3_key)
      return failure("missing_stored_file", attachment.id) unless File.exist?(storage_path)

      extracted_text = extract_text(storage_path: storage_path, mime_type: attachment.mime_type)

      {
        status: :ok,
        attachment_id: attachment.id,
        extracted_text: extracted_text
      }
    rescue StandardError => e
      failure("#{e.class}: #{e.message}", @attachment_id)
    end

    private

    def resolve_storage_path(storage_key)
      return storage_key if storage_key.to_s.start_with?("/")

      Rails.root.join(storage_key)
    end

    def extract_text(storage_path:, mime_type:)
      return nil unless text_extractable?(storage_path: storage_path, mime_type: mime_type)

      File.read(storage_path).to_s
        .encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
        .truncate(MAX_EXTRACTED_TEXT_LENGTH)
    end

    def text_extractable?(storage_path:, mime_type:)
      normalized_mime = mime_type.to_s.downcase
      return true if normalized_mime.start_with?("text/")
      return true if normalized_mime.include?("json")
      return true if normalized_mime.include?("xml")
      return true if normalized_mime.include?("csv")

      extension = File.extname(storage_path.to_s).downcase
      %w[.txt .csv .json .xml .md .log].include?(extension)
    end

    def failure(error_message, attachment_id)
      { status: :failed, attachment_id: attachment_id, error: error_message }
    end
  end
end
