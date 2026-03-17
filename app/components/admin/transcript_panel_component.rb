module Admin
  class TranscriptPanelComponent < ViewComponent::Base
    def initialize(messages:)
      @messages = messages
    end
  end
end
