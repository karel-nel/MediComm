class ApplyFieldCandidatesJob < ApplicationJob
  queue_as :extraction

  # @param intake_session_id [Integer]
  def perform(intake_session_id:)
    Fields::ApplyCandidates.call(intake_session_id: intake_session_id)
  end
end
