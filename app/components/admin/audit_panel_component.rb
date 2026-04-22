module Admin
  class AuditPanelComponent < ViewComponent::Base
    CALLBACK_EVENT_TYPES = %w[n8n_triggered n8n_response_applied].freeze

    def initialize(events:)
      @events = events
    end

    def missing_source_message_id?(event)
      return false unless CALLBACK_EVENT_TYPES.include?(event.event_type.to_s)

      payload = event.payload_json.to_h
      source_message_id = payload["source_message_id"] || payload[:source_message_id]
      source_message_id.to_s.strip.blank?
    end
  end
end
