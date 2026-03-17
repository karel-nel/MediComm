class Admin::DashboardController < Admin::BaseController
  def index
    @metrics = Admin::DashboardMetrics.new(practice: current_practice)
    @recent_queue = @metrics.recent_queue
    @recent_activity = @metrics.recent_activity
    @channel_health = @metrics.channel_health
  end
end
