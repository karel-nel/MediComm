module Admin
  class EmptyStateComponent < ViewComponent::Base
    def initialize(title:, description:)
      @title = title
      @description = description
    end
  end
end
