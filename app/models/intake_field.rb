class IntakeField < ApplicationRecord
  FIELD_TYPES = %w[text long_text date datetime phone email number boolean file select].freeze
  SOURCE_PREFERENCES = %w[any text attachment ocr].freeze
  CLUSTER_SYNC_THREAD_KEY = :intake_field_cluster_sync_in_progress

  belongs_to :intake_flow
  belongs_to :intake_field_group, optional: true

  has_many :intake_field_values, dependent: :restrict_with_exception
  scope :active, -> { where(active: true) }
  after_save :sync_bidirectional_cluster_links!, if: :sync_cluster_links?

  validates :key, :label, :field_type, :source_preference, presence: true
  validates :key, uniqueness: { scope: :intake_flow_id }
  validates :field_type, inclusion: { in: FIELD_TYPES }
  validates :source_preference, inclusion: { in: SOURCE_PREFERENCES }
  validates :required, :extraction_enabled, :active, inclusion: { in: [ true, false ] }
  validates :ask_priority, numericality: { greater_than_or_equal_to: 0 }

  def linked_field_keys
    rules = normalize_rules_hash(branching_rules_json)
    raw_keys = rules["linked_field_keys"] || []

    Array(raw_keys)
      .flat_map { |entry| entry.to_s.split(",") }
      .map(&:strip)
      .reject(&:blank?)
      .uniq
  end

  def linked_field_keys=(value)
    rules = normalize_rules_hash(branching_rules_json)
    normalized_keys = Array(value)
      .flat_map { |entry| entry.to_s.split(",") }
      .map(&:strip)
      .reject(&:blank?)
      .uniq

    normalized_keys -= [ key.to_s ] if key.present?

    if normalized_keys.empty?
      rules.delete("linked_field_keys")
    else
      rules["linked_field_keys"] = normalized_keys
    end

    self.branching_rules_json = rules
  end

  private

  def sync_cluster_links?
    saved_change_to_branching_rules_json? && !self.class.cluster_sync_in_progress?
  end

  def sync_bidirectional_cluster_links!
    previous_keys = previous_linked_field_keys
    current_keys = linked_field_keys
    removed_keys = previous_keys - current_keys
    return if current_keys.empty? && removed_keys.empty?

    self.class.with_cluster_sync do
      sync_reverse_links_for(current_keys)
      remove_reverse_links_for(removed_keys)
    end
  end

  def previous_linked_field_keys
    old_rules = saved_change_to_branching_rules_json&.first
    extract_linked_field_keys_from_rules(old_rules)
  end

  def sync_reverse_links_for(keys)
    target_fields_for(keys).find_each do |target_field|
      next if target_field.key == key
      next if target_field.linked_field_keys.include?(key)

      target_field.linked_field_keys = target_field.linked_field_keys + [ key ]
      target_field.save!
    end
  end

  def remove_reverse_links_for(keys)
    target_fields_for(keys).find_each do |target_field|
      next if target_field.key == key
      next unless target_field.linked_field_keys.include?(key)

      target_field.linked_field_keys = target_field.linked_field_keys - [ key ]
      target_field.save!
    end
  end

  def target_fields_for(keys)
    return IntakeField.none if intake_flow.blank?
    normalized_keys = Array(keys).map(&:to_s).reject(&:blank?).uniq
    return IntakeField.none if normalized_keys.empty?

    intake_flow.intake_fields.where(key: normalized_keys).where.not(id: id)
  end

  def extract_linked_field_keys_from_rules(rules)
    normalized_rules = normalize_rules_hash(rules)
    raw_keys = normalized_rules["linked_field_keys"] || []

    Array(raw_keys)
      .flat_map { |entry| entry.to_s.split(",") }
      .map(&:strip)
      .reject(&:blank?)
      .uniq
  end

  def normalize_rules_hash(value)
    hash = value.is_a?(Hash) ? value.deep_dup : {}
    hash.deep_stringify_keys
  end

  def self.cluster_sync_in_progress?
    Thread.current[CLUSTER_SYNC_THREAD_KEY] == true
  end

  def self.with_cluster_sync
    previous = Thread.current[CLUSTER_SYNC_THREAD_KEY]
    Thread.current[CLUSTER_SYNC_THREAD_KEY] = true
    yield
  ensure
    Thread.current[CLUSTER_SYNC_THREAD_KEY] = previous
  end
end
