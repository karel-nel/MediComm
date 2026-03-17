require "json"

module Whatsapp
  class WebhookParser
    class ParseError < StandardError; end

    def self.call(payload:)
      new(payload: payload).call
    end

    def initialize(payload:)
      @payload = payload
    end

    def call
      raw_hash = normalize_payload(@payload)

      {
        provider: "whatsapp_cloud_api",
        received_at: Time.current.iso8601,
        entries: Array(raw_hash["entry"] || raw_hash[:entry]),
        raw: raw_hash
      }
    rescue JSON::ParserError => e
      raise ParseError, e.message
    end

    private

    def normalize_payload(payload)
      return payload if payload.is_a?(Hash)

      JSON.parse(payload.to_s)
    end
  end
end
