module Whatsapp
  class InboundEventExtractor
    MEDIA_MESSAGE_TYPES = %w[image document audio video sticker].freeze
    DEFAULT_MIME_TYPE_BY_MESSAGE_TYPE = {
      "image" => "image/jpeg",
      "document" => "application/octet-stream",
      "audio" => "audio/ogg",
      "video" => "video/mp4",
      "sticker" => "image/webp"
    }.freeze

    def self.call(parsed_event:)
      new(parsed_event: parsed_event).call
    end

    def initialize(parsed_event:)
      @parsed_event = parsed_event || {}
    end

    def call
      entries.flat_map do |entry|
        changes_for(entry).flat_map do |change|
          value = change["value"] || {}
          metadata = value["metadata"] || {}
          contacts = Array(value["contacts"])
          contact = contacts.first || {}
          profile = contact["profile"] || {}

          Array(value["messages"]).filter_map do |message|
            next unless message["id"].present?

            {
              phone_number_id: metadata["phone_number_id"].to_s,
              display_phone_number: metadata["display_phone_number"].to_s,
              provider_message_id: message["id"].to_s,
              message_type: message["type"].to_s.presence || "text",
              text_body: message.dig("text", "body").to_s,
              attachments: extract_attachments(message),
              from_wa_id: message["from"].to_s,
              patient_phone_e164: normalize_phone(message["from"]),
              patient_display_name: profile["name"].to_s,
              provider_timestamp: parse_timestamp(message["timestamp"]),
              raw_change: change,
              raw_message: message
            }
          end
        end
      end
    end

    private

    def entries
      Array(@parsed_event[:entries] || @parsed_event["entries"] || @parsed_event.dig(:raw, "entry"))
    end

    def changes_for(entry)
      Array(entry["changes"] || entry[:changes]).select do |change|
        change["field"] == "messages" || change[:field] == "messages"
      end
    end

    def normalize_phone(raw_value)
      digits = raw_value.to_s.gsub(/[^\d+]/, "")
      return if digits.blank?
      return digits if digits.start_with?("+")

      "+#{digits}"
    end

    def parse_timestamp(raw_timestamp)
      Time.zone.at(raw_timestamp.to_i)
    rescue StandardError
      Time.current
    end

    def extract_attachments(message)
      message_type = message["type"].to_s
      return [] unless MEDIA_MESSAGE_TYPES.include?(message_type)

      payload = message[message_type] || {}
      media_id = payload["id"].to_s.strip
      return [] if media_id.blank?

      mime_type = payload["mime_type"].to_s.strip
      mime_type = DEFAULT_MIME_TYPE_BY_MESSAGE_TYPE[message_type] if mime_type.blank?

      [
        {
          media_id: media_id,
          media_type: message_type,
          mime_type: mime_type,
          file_name: payload["filename"].to_s.presence || fallback_file_name(media_id: media_id, message_type: message_type, mime_type: mime_type),
          byte_size: normalize_byte_size(payload["file_size"] || payload["size"]),
          caption: payload["caption"].to_s.presence,
          sha256: payload["sha256"].to_s.presence,
          raw_attachment: payload
        }
      ]
    end

    def fallback_file_name(media_id:, message_type:, mime_type:)
      extension = extension_for(mime_type)
      "#{message_type}-#{media_id}.#{extension}"
    end

    def extension_for(mime_type)
      extension = mime_type.to_s.split("/").last.to_s.split(";").first.to_s.downcase
      return "jpg" if extension == "jpeg"
      return "bin" if extension.blank?

      extension
    end

    def normalize_byte_size(value)
      return nil if value.nil?

      size = value.to_i
      size.positive? ? size : nil
    end
  end
end
