class ApplyFieldCandidatesJob < ApplicationJob
  sidekiq_options queue: "extraction"

  # @param payload [Hash]
  def perform(payload = {})
    normalized_payload = payload.to_h.with_indifferent_access
    intake_session = IntakeSession.find(normalized_payload.fetch(:intake_session_id))
    candidate_fields = Array(normalized_payload[:candidate_fields])
    source_message_id = normalized_payload[:source_message_id]
    source_message = source_message_id.present? ? intake_session.intake_messages.find_by(provider_message_id: source_message_id) : nil

    Fields::ApplyCandidates.call(
      intake_session: intake_session,
      candidate_fields: candidate_fields,
      source_message: source_message,
      applied_by: "apply_field_candidates_job"
    )
  end
end
