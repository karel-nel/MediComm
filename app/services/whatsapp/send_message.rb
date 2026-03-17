require "json"
require "net/http"
require "uri"

module Whatsapp
  class SendMessage
    DEFAULT_GRAPH_VERSION = "v22.0".freeze
    DEFAULT_TIMEOUT_SECONDS = 10

    def self.call(intake_session_id:, message_body:)
      new(intake_session_id: intake_session_id, message_body: message_body).call
    end

    def initialize(intake_session_id:, message_body:)
      @intake_session_id = intake_session_id
      @message_body = message_body
    end

    def call
      session = IntakeSession.includes(:whatsapp_account).find(@intake_session_id)
      account = session.whatsapp_account
      access_token = account.access_token_ciphertext.to_s.strip
      return skipped_response("missing_access_token") if access_token.blank?

      uri = URI.parse("https://graph.facebook.com/#{graph_version}/#{account.phone_number_id}/messages")
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{access_token}"
      request["Content-Type"] = "application/json"
      request.body = {
        messaging_product: "whatsapp",
        recipient_type: "individual",
        to: normalized_recipient(session.patient_phone_e164),
        type: "text",
        text: { body: @message_body.to_s.strip.presence || fallback_body }
      }.to_json

      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: true,
        open_timeout: DEFAULT_TIMEOUT_SECONDS,
        read_timeout: DEFAULT_TIMEOUT_SECONDS
      ) do |http|
        http.request(request)
      end

      parsed_body = parse_json(response.body)
      provider_message_id = parsed_body.dig("messages", 0, "id")

      {
        status: response.is_a?(Net::HTTPSuccess) ? :sent : :failed,
        intake_session_id: @intake_session_id,
        message_preview: @message_body.to_s.truncate(80),
        provider_message_id: provider_message_id,
        code: response.code.to_i,
        response_body: parsed_body
      }
    rescue StandardError => e
      Rails.logger.error("[Whatsapp::SendMessage] session=#{@intake_session_id} failed: #{e.class}: #{e.message}")
      {
        status: :failed,
        intake_session_id: @intake_session_id,
        message_preview: @message_body.to_s.truncate(80),
        provider_message_id: nil,
        error: e.message
      }
    end

    private

    def graph_version
      ENV.fetch("WHATSAPP_GRAPH_VERSION", DEFAULT_GRAPH_VERSION)
    end

    def normalized_recipient(phone)
      phone.to_s.delete_prefix("+")
    end

    def parse_json(raw_body)
      JSON.parse(raw_body.to_s)
    rescue JSON::ParserError
      { "raw" => raw_body.to_s }
    end

    def fallback_body
      "Thank you, we received your message and will continue shortly."
    end

    def skipped_response(reason)
      {
        status: :skipped,
        intake_session_id: @intake_session_id,
        message_preview: @message_body.to_s.truncate(80),
        provider_message_id: nil,
        reason: reason
      }
    end
  end
end
