require "json"
require "net/http"
require "uri"

module Whatsapp
  class SendTemplateMessage
    DEFAULT_GRAPH_VERSION = "v22.0".freeze
    DEFAULT_TIMEOUT_SECONDS = 10
    DEFAULT_LANGUAGE_CODE = "en".freeze

    def self.call(intake_session_id:, template_name: nil, language_code: nil, body_parameters: [])
      new(
        intake_session_id: intake_session_id,
        template_name: template_name,
        language_code: language_code,
        body_parameters: body_parameters
      ).call
    end

    def initialize(intake_session_id:, template_name: nil, language_code: nil, body_parameters: [])
      @intake_session_id = intake_session_id
      @template_name = template_name
      @language_code = language_code
      @body_parameters = Array(body_parameters)
    end

    def call
      session = IntakeSession.includes(:whatsapp_account).find(@intake_session_id)
      account = session.whatsapp_account
      access_token = account.access_token_ciphertext.to_s.strip
      return skipped_response(reason: "missing_access_token") if access_token.blank?

      resolved_template_name = template_name
      return skipped_response(reason: "missing_template_name") if resolved_template_name.blank?

      uri = URI.parse("https://graph.facebook.com/#{graph_version}/#{account.phone_number_id}/messages")
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{access_token}"
      request["Content-Type"] = "application/json"
      request.body = {
        messaging_product: "whatsapp",
        recipient_type: "individual",
        to: normalized_recipient(session.patient_phone_e164),
        type: "template",
        template: {
          name: resolved_template_name,
          language: { code: language_code },
          components: template_components
        }
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
        template_name: resolved_template_name,
        language_code: language_code,
        body_parameters: sanitized_parameters,
        provider_message_id: provider_message_id,
        code: response.code.to_i,
        response_body: parsed_body
      }
    rescue StandardError => e
      Rails.logger.error("[Whatsapp::SendTemplateMessage] session=#{@intake_session_id} failed: #{e.class}: #{e.message}")
      {
        status: :failed,
        intake_session_id: @intake_session_id,
        template_name: template_name,
        language_code: language_code,
        body_parameters: sanitized_parameters,
        provider_message_id: nil,
        error: e.message
      }
    end

    private

    def graph_version
      ENV.fetch("WHATSAPP_GRAPH_VERSION", DEFAULT_GRAPH_VERSION)
    end

    def template_name
      @template_name.to_s.strip.presence || ENV["WHATSAPP_FOLLOW_UP_TEMPLATE_ID"].to_s.strip.presence
    end

    def language_code
      @language_code.to_s.strip.presence || ENV.fetch("WHATSAPP_FOLLOW_UP_TEMPLATE_LANGUAGE", DEFAULT_LANGUAGE_CODE)
    end

    def normalized_recipient(phone)
      phone.to_s.delete_prefix("+")
    end

    def parse_json(raw_body)
      JSON.parse(raw_body.to_s)
    rescue JSON::ParserError
      { "raw" => raw_body.to_s }
    end

    def sanitized_parameters
      @sanitized_parameters ||= @body_parameters
        .map { |value| value.to_s.squish }
        .reject(&:blank?)
    end

    def template_components
      return [] if sanitized_parameters.empty?

      [
        {
          type: "body",
          parameters: sanitized_parameters.map { |value| { type: "text", text: value } }
        }
      ]
    end

    def skipped_response(reason:)
      {
        status: :skipped,
        intake_session_id: @intake_session_id,
        template_name: template_name,
        language_code: language_code,
        body_parameters: sanitized_parameters,
        provider_message_id: nil,
        reason: reason
      }
    end
  end
end
