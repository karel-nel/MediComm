return unless defined?(Sidekiq)

# Sidekiq is our production job backend. Keep queue names explicit so upcoming
# WhatsApp/media/AI pipeline work can be rolled out in bounded steps.
redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/1")
sidekiq_redis_config = { url: redis_url }

Sidekiq.strict_args!(:log)

Sidekiq.configure_server do |config|
  config.redis = sidekiq_redis_config
end

Sidekiq.configure_client do |config|
  config.redis = sidekiq_redis_config
end
