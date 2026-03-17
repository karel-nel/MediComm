require "json"
require "net/http"
require "uri"

module N8n
  class TriggerConversationAgent
    DEFAULT_TIMEOUT_SECONDS = 8

    def self.call(payload:, intake_session:)
      new(payload: payload, intake_session: intake_session).call
    end

    def initialize(payload:, intake_session:)
      @payload = payload
      @intake_session = intake_session
    end

    def call
      return skipped_result("missing_n8n_webhook_url") if webhook_url.blank?

      uri = URI.parse(webhook_url)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["Authorization"] = "Bearer #{bearer_token}" if bearer_token.present?
      request.body = payload.to_json

      response = with_http(uri) { |http| http.request(request) }

      {
        status: response.is_a?(Net::HTTPSuccess) ? :ok : :failed,
        code: response.code.to_i,
        response_body: response.body.to_s.truncate(1000)
      }
    rescue StandardError => e
      Rails.logger.error("[N8n::TriggerConversationAgent] session=#{intake_session.id} failed: #{e.class}: #{e.message}")
      { status: :failed, error: e.message }
    end

    private

    attr_reader :intake_session, :payload

    def webhook_url
      ENV["N8N_CONVERSATION_WEBHOOK_URL"].to_s.strip
    end

    def bearer_token
      ENV["N8N_BEARER_TOKEN"].to_s.strip
    end

    def with_http(uri)
      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: DEFAULT_TIMEOUT_SECONDS,
        read_timeout: DEFAULT_TIMEOUT_SECONDS
      ) do |http|
        yield http
      end
    end

    def skipped_result(reason)
      Rails.logger.info("[N8n::TriggerConversationAgent] session=#{intake_session.id} skipped: #{reason}")
      { status: :skipped, reason: reason }
    end
  end
end
