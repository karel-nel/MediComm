class Admin::FieldsController < Admin::BaseController
  before_action :set_flow
  before_action :set_field, only: [ :edit, :update, :destroy, :archive, :move ]

  def new
    @field = @flow.intake_fields.new(
      active: true,
      required: true,
      extraction_enabled: true,
      source_preference: "any",
      field_type: "text",
      ask_priority: next_priority
    )
  end

  def create
    @field = @flow.intake_fields.new(field_params)
    return render_invalid_field!("Could not create field.") unless normalize_group_scope!(@field)
    return render_invalid_field!("Could not create field.") unless apply_json_attributes(@field)

    if @field.save
      redirect_to admin_flow_path(@flow), notice: "Field created."
    else
      render_invalid_field!("Could not create field.")
    end
  end

  def edit
  end

  def update
    @field.assign_attributes(field_params)
    return render_invalid_field!("Could not update field.") unless normalize_group_scope!(@field)
    return render_invalid_field!("Could not update field.") unless apply_json_attributes(@field)

    if @field.save
      redirect_to admin_flow_path(@flow), notice: "Field updated."
    else
      render_invalid_field!("Could not update field.")
    end
  end

  def move
    direction = params[:direction].to_s
    comparator = direction == "up" ? "<" : ">"
    order = direction == "up" ? :desc : :asc

    target_scope = @flow.intake_fields.active.where(intake_field_group_id: @field.intake_field_group_id)
    target = target_scope.where("ask_priority #{comparator} ?", @field.ask_priority).order(ask_priority: order).first
    return redirect_to(admin_flow_path(@flow), alert: "Cannot move this field further.") unless target

    ActiveRecord::Base.transaction do
      original_priority = @field.ask_priority
      @field.update!(ask_priority: target.ask_priority)
      target.update!(ask_priority: original_priority)
    end

    redirect_to admin_flow_path(@flow), notice: "Field order updated."
  end

  def archive
    archive_field!
    redirect_to admin_flow_path(@flow), notice: "Field archived."
  end

  def destroy
    archive_field!
    redirect_to admin_flow_path(@flow), notice: "Field archived."
  end

  private

  def set_flow
    @flow = current_practice.intake_flows.find(params[:flow_id])
  end

  def set_field
    @field = @flow.intake_fields.find(params[:id])
  end

  def field_params
    params.require(:intake_field).permit(
      :intake_field_group_id,
      :key,
      :label,
      :field_type,
      :required,
      :ask_priority,
      :extraction_enabled,
      :source_preference,
      :ai_prompt_hint,
      :autofill_pdf_key,
      :active
    )
  end

  def apply_json_attributes(field)
    validation_rules = parse_json_object(:validation_rules_text, field.validation_rules_json)
    branching_rules = parse_json_object(:branching_rules_text, field.branching_rules_json)
    skip_rules = parse_json_object(:skip_rules_text, field.skip_rules_json)
    example_values = parse_json_array(:example_values_text, field.example_values_json)
    return false if [ validation_rules, branching_rules, skip_rules, example_values ].any?(&:nil?)

    field.validation_rules_json = validation_rules
    field.branching_rules_json = branching_rules
    field.skip_rules_json = skip_rules
    field.example_values_json = example_values
    true
  end

  def parse_json_object(param_key, fallback)
    raw = params.dig(:intake_field, param_key).to_s
    return fallback || {} if raw.blank?

    parsed = JSON.parse(raw)
    return parsed if parsed.is_a?(Hash)

    @field.errors.add(param_key.to_s.sub("_text", ""), "must be a JSON object")
    nil
  rescue JSON::ParserError
    @field.errors.add(param_key.to_s.sub("_text", ""), "must be valid JSON")
    nil
  end

  def parse_json_array(param_key, fallback)
    raw = params.dig(:intake_field, param_key).to_s
    return fallback || [] if raw.blank?

    parsed = JSON.parse(raw)
    return parsed if parsed.is_a?(Array)

    @field.errors.add(param_key.to_s.sub("_text", ""), "must be a JSON array")
    nil
  rescue JSON::ParserError
    @field.errors.add(param_key.to_s.sub("_text", ""), "must be valid JSON")
    nil
  end

  def next_priority
    @flow.intake_fields.active.maximum(:ask_priority).to_i + 1
  end

  def archive_field!
    archived_key = "#{@field.key}_archived_#{@field.id}"
    @field.update!(active: false, key: archived_key)
  end

  def normalize_group_scope!(field)
    group_id = field.intake_field_group_id
    return true if group_id.blank?
    return true if @flow.intake_field_groups.active.exists?(id: group_id)

    field.errors.add(:intake_field_group_id, "must belong to this flow")
    false
  end

  def render_invalid_field!(message)
    flash.now[:alert] = message
    render(action_name == "create" ? :new : :edit, status: :unprocessable_entity)
  end
end
