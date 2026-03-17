module Admin
  class StatusBadgeComponent < ViewComponent::Base
    def initialize(value:, context: nil)
      @value = value.to_s
      @context = context.to_s.presence
    end

    private

    def label
      @value.to_s.humanize
    end

    def classes
      case normalized_key
      when "active", "connected", "healthy", "approved", "complete", "completed", "high_confidence"
        "bg-emerald-50 text-emerald-700 ring-emerald-100"
      when "awaiting_staff_review", "awaiting_review", "pending", "medium_confidence", "candidate", "processing"
        "bg-amber-50 text-amber-700 ring-amber-100"
      when "needs_follow_up", "needs_clarification", "missing", "failed", "low_confidence", "abandoned", "rejected", "paused"
        "bg-rose-50 text-rose-700 ring-rose-100"
      when "draft", "disabled", "archived"
        "bg-slate-100 text-slate-600 ring-slate-200"
      else
        "bg-slate-100 text-slate-700 ring-slate-200"
      end
    end

    def normalized_key
      return "#{@value}_confidence" if @context == "confidence"

      @value
    end
  end
end
