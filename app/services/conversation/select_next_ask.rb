module Conversation
  class SelectNextAsk
    def self.call(intake_session:)
      new(intake_session: intake_session).call
    end

    def initialize(intake_session:)
      @intake_session = intake_session
    end

    def call
      outstanding = Fields::ComputeOutstanding.call(intake_session: @intake_session)
      batches = Array(outstanding[:next_ask_batches])
      return nil if batches.empty?

      batch = batches.first
      field_keys = Array(batch[:field_keys]).map(&:to_s).reject(&:blank?).uniq
      fields = Array(batch[:fields]).select { |field| field[:key].present? }

      {
        mode: field_keys.length > 1 ? "cluster" : "single",
        cluster_key: batch[:batch_key].to_s,
        group_key: batch[:group_key].to_s.presence,
        group_label: batch[:group_label].to_s.presence,
        field_keys: field_keys,
        fields: fields
      }
    end
  end
end
