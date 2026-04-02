require "json"
require "net/http"
require "uri"
require "fileutils"

module Attachments
  class DownloadFromMeta
    GRAPH_API_BASE_URL = "https://graph.facebook.com/v23.0".freeze
    HTTP_TIMEOUT_SECONDS = 15

    def self.call(attachment_id:, media_id:, whatsapp_account_id: nil)
      new(attachment_id: attachment_id, media_id: media_id, whatsapp_account_id: whatsapp_account_id).call
    end

    def initialize(attachment_id:, media_id:, whatsapp_account_id: nil)
      @attachment_id = attachment_id
      @media_id = media_id.to_s
      @whatsapp_account_id = whatsapp_account_id
    end

    def call
      return failure("missing_media_id") if media_id.blank?

      attachment = IntakeAttachment.find(attachment_id)
      return stubbed_download(attachment) if stub_download?

      account = resolve_whatsapp_account(attachment)
      return failure("missing_whatsapp_account") if account.blank?

      access_token = account.access_token_ciphertext.to_s
      return failure("missing_access_token") if access_token.blank?

      media_metadata = fetch_media_metadata(access_token)
      media_url = media_metadata["url"].to_s
      return failure("missing_media_url") if media_url.blank?

      media_response = perform_get(uri: URI.parse(media_url), bearer_token: access_token)
      return failure("media_download_failed: #{media_response.code}") unless media_response.is_a?(Net::HTTPSuccess)

      temp_path = build_temp_path(attachment)
      File.binwrite(temp_path, media_response.body.to_s)

      {
        status: :ok,
        attachment_id: attachment.id,
        temp_path: temp_path.to_s,
        content_type: media_response["Content-Type"].to_s.presence || media_metadata["mime_type"].to_s.presence || attachment.mime_type,
        byte_size: File.size(temp_path)
      }
    rescue StandardError => e
      failure("#{e.class}: #{e.message}")
    end

    private

    attr_reader :attachment_id, :media_id, :whatsapp_account_id

    def stub_download?
      return truthy?(ENV["WHATSAPP_MEDIA_DOWNLOAD_STUB"]) if ENV.key?("WHATSAPP_MEDIA_DOWNLOAD_STUB")

      Rails.env.development? || Rails.env.test?
    end

    def fetch_media_metadata(access_token)
      uri = URI.parse("#{GRAPH_API_BASE_URL}/#{media_id}")
      response = perform_get(uri: uri, bearer_token: access_token)
      raise "media_metadata_failed: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body.to_s)
    end

    def perform_get(uri:, bearer_token:)
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{bearer_token}"

      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: HTTP_TIMEOUT_SECONDS,
        read_timeout: HTTP_TIMEOUT_SECONDS
      ) do |http|
        http.request(request)
      end
    end

    def stubbed_download(attachment)
      temp_path = build_temp_path(attachment)
      content = "stub-whatsapp-media attachment=#{attachment.id} media_id=#{media_id}\n"
      File.binwrite(temp_path, content)

      {
        status: :ok,
        attachment_id: attachment.id,
        temp_path: temp_path.to_s,
        content_type: attachment.mime_type.presence || "application/octet-stream",
        byte_size: File.size(temp_path)
      }
    end

    def build_temp_path(attachment)
      directory = Rails.root.join("tmp", "whatsapp_media", "downloads")
      FileUtils.mkdir_p(directory)

      extension = extension_for(attachment.mime_type)
      directory.join("#{attachment.id}-#{media_id}.#{extension}")
    end

    def extension_for(mime_type)
      extension = mime_type.to_s.split("/").last.to_s.split(";").first
      return "jpg" if extension == "jpeg"
      return "bin" if extension.blank?

      extension
    end

    def resolve_whatsapp_account(attachment)
      return WhatsappAccount.find_by(id: whatsapp_account_id) if whatsapp_account_id.present?

      attachment.intake_session.whatsapp_account
    end

    def truthy?(value)
      ActiveModel::Type::Boolean.new.cast(value)
    end

    def failure(error_message)
      { status: :failed, attachment_id: attachment_id, error: error_message }
    end
  end
end
