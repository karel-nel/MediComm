module Admin
  class TopbarComponent < ViewComponent::Base
    def initialize(user:, practice:)
      @user = user
      @practice = practice
    end

    def user_initials
      return "MC" unless @user

      [ @user.first_name, @user.last_name ].map { |name| name.to_s.first }.join.upcase
    end

    def practice_label
      @practice&.name.presence || "Practice"
    end

    def practice_slug
      @practice&.slug.presence || "unknown"
    end
  end
end
