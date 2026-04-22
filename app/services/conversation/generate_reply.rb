module Conversation
  class GenerateReply
    def self.call(intake_session_id:)
      new(intake_session_id: intake_session_id).call
    end

    def initialize(intake_session_id:)
      @intake_session_id = intake_session_id
    end

    def call
      intake_session = IntakeSession.find(@intake_session_id)
      next_ask = Conversation::SelectNextAsk.call(intake_session: intake_session)
      reply_text = build_reply_text(next_ask)

      {
        status: :ok,
        intake_session_id: @intake_session_id,
        reply_text: reply_text,
        next_ask: next_ask
      }
    end

    private

    def build_reply_text(next_ask)
      return fallback_reply if next_ask.blank?

      field_labels = Array(next_ask[:fields]).map { |field| field[:label].to_s.strip }.reject(&:blank?)
      return fallback_reply if field_labels.empty?

      return "Thank you. Please share your #{field_labels.first}." if field_labels.size == 1

      question_list = field_labels.map { |label| "- #{label}" }.join("\n")
      "Thank you. Please share the following details so we can continue:\n#{question_list}"
    end

    def fallback_reply
      "Thank you, we received your message and will continue shortly."
    end
  end
end
