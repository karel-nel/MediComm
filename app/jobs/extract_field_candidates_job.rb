class ExtractFieldCandidatesJob < ApplicationJob
  sidekiq_options queue: "extraction"

  # @param payload [Hash]
  def perform(payload = {})
    normalized_payload = payload.to_h.with_indifferent_access
    Fields::ExtractCandidates.call(intake_session_id: normalized_payload.fetch(:intake_session_id))
  end
end
