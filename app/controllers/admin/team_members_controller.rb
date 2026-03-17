class Admin::TeamMembersController < Admin::BaseController
  before_action :ensure_management_access!
  before_action :set_team_member, only: [ :edit, :update, :deactivate, :reactivate ]

  def index
    @team_members = current_practice.users.order(:first_name, :last_name)
    @active_count = current_practice.users.where(active: true).count
    @owner_count = current_practice.users.where(role: User.roles[:owner]).count
  end

  def new
    @team_member = current_practice.users.new(role: :staff, active: true)
  end

  def create
    @team_member = current_practice.users.new(create_params)

    if @team_member.save
      redirect_to admin_team_members_path, notice: "Team member created."
    else
      flash.now[:alert] = "Could not create team member."
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if demoting_last_owner?
      return redirect_to(admin_team_members_path, alert: "Cannot remove role from the only owner.")
    end
    if deactivating_last_owner_via_update?
      return redirect_to(admin_team_members_path, alert: "Cannot deactivate the only owner.")
    end

    if @team_member.update(update_params)
      redirect_to admin_team_members_path, notice: "Team member updated."
    else
      flash.now[:alert] = "Could not update team member."
      render :edit, status: :unprocessable_entity
    end
  end

  def deactivate
    if @team_member == current_user
      return redirect_to(admin_team_members_path, alert: "You cannot deactivate your own account.")
    end
    if deactivating_last_owner?
      return redirect_to(admin_team_members_path, alert: "Cannot deactivate the only owner.")
    end

    @team_member.update!(active: false)
    redirect_to admin_team_members_path, notice: "Team member deactivated."
  end

  def reactivate
    @team_member.update!(active: true)
    redirect_to admin_team_members_path, notice: "Team member reactivated."
  end

  private

  def set_team_member
    @team_member = current_practice.users.find(params[:id])
  end

  def ensure_management_access!
    return if current_user.role_owner? || current_user.role_admin?

    redirect_to admin_root_path, alert: "You do not have permission to manage team members."
  end

  def create_params
    params.require(:user).permit(
      :first_name,
      :last_name,
      :email,
      :role,
      :active,
      :password,
      :password_confirmation
    ).merge(practice: current_practice)
  end

  def update_params
    permitted = params.require(:user).permit(
      :first_name,
      :last_name,
      :email,
      :role,
      :active,
      :password,
      :password_confirmation
    )

    if permitted[:password].blank? && permitted[:password_confirmation].blank?
      permitted.except(:password, :password_confirmation)
    else
      permitted
    end
  end

  def deactivating_last_owner?
    @team_member.role_owner? && current_practice.users.where(role: User.roles[:owner], active: true).count <= 1
  end

  def demoting_last_owner?
    return false unless @team_member.role_owner?
    return false if params.dig(:user, :role).to_s == "owner"

    current_practice.users.where(role: User.roles[:owner], active: true).count <= 1
  end

  def deactivating_last_owner_via_update?
    return false unless @team_member.role_owner?
    return false unless params.dig(:user, :active).to_s == "0"

    current_practice.users.where(role: User.roles[:owner], active: true).count <= 1
  end
end
