module Admin
  class MetricCardComponent < ViewComponent::Base
    def initialize(label:, value:, support_text:, tone: :neutral)
      @label = label
      @value = value
      @support_text = support_text
      @tone = tone
    end

    private

    def accent_classes
      case @tone.to_sym
      when :teal
        "from-teal-500/10 to-teal-50 text-teal-700"
      when :blue
        "from-blue-500/10 to-blue-50 text-blue-700"
      when :amber
        "from-amber-500/10 to-amber-50 text-amber-700"
      else
        "from-slate-500/10 to-slate-50 text-slate-700"
      end
    end
  end
end
