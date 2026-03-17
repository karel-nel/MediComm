module Fields
  class ExtractCandidates
    def self.call(intake_session_id:)
      new(intake_session_id: intake_session_id).call
    end

    def initialize(intake_session_id:)
      @intake_session_id = intake_session_id
    end

    def call
      # TODO: Gather transcript + attachment text and request AI candidate extraction.
      []
    end
  end
end
