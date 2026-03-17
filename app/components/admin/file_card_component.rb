module Admin
  class FileCardComponent < ViewComponent::Base
    def initialize(attachment:)
      @attachment = attachment
    end

    private

    def icon_label
      case @attachment.mime_type
      when /image/
        "IMG"
      when /pdf/
        "PDF"
      else
        "DOC"
      end
    end
  end
end
