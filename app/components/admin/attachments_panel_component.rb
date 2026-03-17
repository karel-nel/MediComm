module Admin
  class AttachmentsPanelComponent < ViewComponent::Base
    def initialize(attachments:)
      @attachments = attachments
    end
  end
end
