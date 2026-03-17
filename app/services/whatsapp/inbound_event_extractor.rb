module Whatsapp
  class InboundEventExtractor
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
  end
end
