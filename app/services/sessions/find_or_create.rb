module Sessions
  class FindOrCreate
    def self.call(parsed_event:)
      new(parsed_event: parsed_event).call
    end

    def initialize(parsed_event:)
      @parsed_event = parsed_event
    end

    def call
      # TODO: Resolve practice + flow + patient identity from webhook payload and return IntakeSession.
      nil
    end
  end
end
