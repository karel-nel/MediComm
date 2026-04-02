require "fileutils"

module Attachments
  class StoreToS3
    def self.call(attachment_id:, source_path: nil, content_type: nil)
      new(attachment_id: attachment_id, source_path: source_path, content_type: content_type).call
    end

    def initialize(attachment_id:, source_path: nil, content_type: nil)
      @attachment_id = attachment_id
      @source_path = source_path
      @content_type = content_type
    end

    def call
      attachment = IntakeAttachment.find(@attachment_id)
      return failure("missing_source_path") if @source_path.blank?
      return failure("missing_source_file") unless File.exist?(@source_path)

      target_path = build_target_path(attachment)
      FileUtils.mkdir_p(target_path.dirname)
      FileUtils.cp(@source_path, target_path)

      storage_key = relativize_storage_path(target_path)
      final_byte_size = File.size(target_path)

      attachment.update!(
        s3_key: storage_key,
        byte_size: final_byte_size,
        mime_type: @content_type.to_s.presence || attachment.mime_type,
        processing_status: "stored_local"
      )

      cleanup_source_path

      {
        status: :ok,
        attachment_id: attachment.id,
        s3_key: storage_key,
        local_path: target_path.to_s,
        byte_size: final_byte_size
      }
    rescue StandardError => e
      failure("#{e.class}: #{e.message}")
    end

    private

    def build_target_path(attachment)
      root = Rails.root.join(Rails.env.test? ? "tmp/storage" : "storage")
      safe_file_name = sanitize_file_name(attachment.file_name)
      root
        .join("intake_attachments")
        .join("practice_#{attachment.intake_session.practice_id}")
        .join("session_#{attachment.intake_session_id}")
        .join("#{attachment.id}_#{safe_file_name}")
    end

    def sanitize_file_name(file_name)
      name = file_name.to_s.strip
      name = "attachment.bin" if name.blank?

      name.gsub(/[^\w.\-]/, "_")
    end

    def relativize_storage_path(pathname)
      pathname.relative_path_from(Rails.root).to_s
    rescue StandardError
      pathname.to_s
    end

    def cleanup_source_path
      return if @source_path.blank?
      return unless File.exist?(@source_path)

      File.delete(@source_path)
    rescue StandardError
      nil
    end

    def failure(error_message)
      { status: :failed, attachment_id: @attachment_id, error: error_message }
    end
  end
end
