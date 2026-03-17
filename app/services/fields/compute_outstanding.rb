module Fields
  class ComputeOutstanding
    def self.call(intake_session:)
      new(intake_session: intake_session).call
    end

    def initialize(intake_session:)
      @intake_session = intake_session
    end

    def call
      # TODO: Return unresolved required fields used for completion checks and next asks.
      []
    end
  end
end
