class Admin::SessionsController < Admin::BaseController
  before_action :set_session, only: [ :show, :approve_review, :request_follow_up, :reopen, :update_review, :assign_owner ]

  def index
    @sessions = Admin::SessionsQuery.new(practice: current_practice, params: params).results
    @flows = current_practice.intake_flows.order(:name)
  end

  def show
    @detail = Admin::SessionDetailPresenter.new(intake_session: @intake_session)
    @active_tab = params[:tab].presence_in(%w[transcript attachments audit]) || "transcript"
  end

  def approve_review
    apply_review_transition!(
      review_status: :approved,
      session_status: :completed,
      notes: params[:notes].presence,
      event_type: "session_review_approved"
    )
    redirect_to admin_session_path(@intake_session), notice: "Session review approved."
  end

  def request_follow_up
    apply_review_transition!(
      review_status: :needs_follow_up,
      session_status: :awaiting_patient,
      notes: params[:notes].presence || "Follow-up requested by reviewer.",
      event_type: "session_follow_up_requested"
    )
    redirect_to admin_session_path(@intake_session), alert: "Follow-up requested."
  end

  def reopen
    ActiveRecord::Base.transaction do
      @intake_session.update!(status: :active, completed_at: nil)
      IntakeEvent.create!(
        intake_session: @intake_session,
        event_type: "session_reopened",
        payload_json: { reopened_by_user_id: current_user.id, reopened_at: Time.current.iso8601 }
      )
    end

    redirect_to admin_session_path(@intake_session), notice: "Session reopened."
  end

  def update_review
    review = ensure_review!
    review_status = params.dig(:session_review, :status).presence || review.status
    notes = params.dig(:session_review, :notes)

    session_status = case review_status.to_s
    when "approved"
      :completed
    when "needs_follow_up"
      :awaiting_patient
    else
      :awaiting_staff_review
    end

    apply_review_transition!(
      review_status: review_status,
      session_status: session_status,
      notes: notes,
      event_type: "session_review_updated"
    )

    redirect_to admin_session_path(@intake_session), notice: "Review updated."
  end

  def assign_owner
    assignee = current_practice.users.find(params.require(:initiated_by_user_id))
    previous_owner_id = @intake_session.initiated_by_user_id

    ActiveRecord::Base.transaction do
      @intake_session.update!(initiated_by_user: assignee)
      IntakeEvent.create!(
        intake_session: @intake_session,
        event_type: "session_owner_reassigned",
        payload_json: {
          previous_owner_id: previous_owner_id,
          new_owner_id: assignee.id,
          reassigned_by_user_id: current_user.id,
          reassigned_at: Time.current.iso8601
        }
      )
    end

    redirect_to admin_session_path(@intake_session), notice: "Session owner updated."
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_session_path(@intake_session), alert: "Invalid owner selection."
  end

  private

  def ensure_review!
    @intake_session.session_review || @intake_session.create_session_review!(reviewer: current_user, status: :pending)
  end

  def apply_review_transition!(review_status:, session_status:, notes:, event_type:)
    ActiveRecord::Base.transaction do
      review = ensure_review!
      review.update!(
        reviewer: current_user,
        status: review_status,
        notes: notes,
        reviewed_at: Time.current
      )
      session_attrs = { status: session_status }
      session_attrs[:completed_at] = Time.current if session_status.to_s == "completed"
      session_attrs[:completed_at] = nil unless session_status.to_s == "completed"
      @intake_session.update!(session_attrs)

      IntakeEvent.create!(
        intake_session: @intake_session,
        event_type: event_type,
        payload_json: {
          session_review_id: review.id,
          review_status: review.status,
          session_status: @intake_session.status,
          reviewer_id: current_user.id,
          notes: notes
        }
      )
    end
  end

  def set_session
    @intake_session = current_practice
      .intake_sessions
      .includes(
        :session_review,
        :initiated_by_user,
        :whatsapp_account,
        :intake_events,
        :intake_messages,
        :intake_attachments,
        intake_flow: [ :intake_fields, :intake_field_groups ],
        intake_field_values: [ :intake_field, :source_message, :source_attachment ]
      )
      .find(params[:id])
  end
end
