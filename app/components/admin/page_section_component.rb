module Admin
  class PageSectionComponent < ViewComponent::Base
    renders_one :actions

    def initialize(title:, description: nil)
      @title = title
      @description = description
    end
  end
end
