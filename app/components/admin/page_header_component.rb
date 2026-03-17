module Admin
  class PageHeaderComponent < ViewComponent::Base
    def initialize(title:, subtitle: nil)
      @title = title
      @subtitle = subtitle
    end
  end
end
