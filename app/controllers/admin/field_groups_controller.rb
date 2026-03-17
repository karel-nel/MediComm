class Admin::FieldGroupsController < Admin::BaseController
  before_action :set_flow
  before_action :set_field_group, only: [ :edit, :update, :destroy, :archive, :move ]

  def new
    @field_group = @flow.intake_field_groups.new(position: next_position)
  end

  def create
    @field_group = @flow.intake_field_groups.new(field_group_params)
    visibility_rules = visibility_rules_payload
    return render_invalid_group!("Could not create field group.") if visibility_rules.nil?
    @field_group.visibility_rules_json = visibility_rules

    if @field_group.save
      redirect_to admin_flow_path(@flow), notice: "Field group created."
    else
      render_invalid_group!("Could not create field group.")
    end
  end

  def edit
  end

  def update
    @field_group.assign_attributes(field_group_params)
    visibility_rules = visibility_rules_payload
    return render_invalid_group!("Could not update field group.") if visibility_rules.nil?
    @field_group.visibility_rules_json = visibility_rules

    if @field_group.save
      redirect_to admin_flow_path(@flow), notice: "Field group updated."
    else
      render_invalid_group!("Could not update field group.")
    end
  end

  def move
    direction = params[:direction].to_s
    comparator = direction == "up" ? "<" : ">"
    order = direction == "up" ? :desc : :asc

    target = @flow.intake_field_groups.active.where("position #{comparator} ?", @field_group.position).order(position: order).first
    return redirect_to(admin_flow_path(@flow), alert: "Cannot move this group further.") unless target

    ActiveRecord::Base.transaction do
      original_position = @field_group.position
      @field_group.update!(position: target.position)
      target.update!(position: original_position)
    end

    redirect_to admin_flow_path(@flow), notice: "Field group order updated."
  end

  def archive
    archive_group!
    redirect_to admin_flow_path(@flow), notice: "Field group archived."
  end

  def destroy
    archive_group!
    redirect_to admin_flow_path(@flow), notice: "Field group archived."
  end

  private

  def set_flow
    @flow = current_practice.intake_flows.find(params[:flow_id])
  end

  def set_field_group
    @field_group = @flow.intake_field_groups.find(params[:id])
  end

  def field_group_params
    params.require(:intake_field_group).permit(:key, :label, :position, :repeatable)
  end

  def visibility_rules_payload
    raw = params.dig(:intake_field_group, :visibility_rules_text).to_s
    return @field_group&.visibility_rules_json || {} if raw.blank?

    JSON.parse(raw)
  rescue JSON::ParserError
    @field_group.errors.add(:visibility_rules_json, "must be valid JSON")
    nil
  end

  def next_position
    @flow.intake_field_groups.active.maximum(:position).to_i + 1
  end

  def archive_group!
    ActiveRecord::Base.transaction do
      archived_key = "#{@field_group.key}_archived_#{@field_group.id}"
      @field_group.intake_fields.update_all(active: false)
      @field_group.update!(archived_at: Time.current, key: archived_key)
    end
  end

  def render_invalid_group!(message)
    flash.now[:alert] = message
    render(action_name == "create" ? :new : :edit, status: :unprocessable_entity)
  end
end
