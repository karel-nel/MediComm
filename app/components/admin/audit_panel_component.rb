module Admin
  class AuditPanelComponent < ViewComponent::Base
    def initialize(events:)
      @events = events
    end
  end
end
