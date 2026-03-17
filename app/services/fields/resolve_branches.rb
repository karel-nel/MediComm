module Fields
  class ResolveBranches
    def self.call(intake_session:)
      new(intake_session: intake_session).call
    end

    def initialize(intake_session:)
      @intake_session = intake_session
    end

    def call
      # TODO: Evaluate branching rules to determine currently active intake fields.
      []
    end
  end
end
