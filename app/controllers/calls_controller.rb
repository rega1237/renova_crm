class CallsController < ApplicationController
  before_action :set_call, only: [:show, :edit, :update]

  PER_PAGE = 20

  def index
    @users = User.order(:name)
    @user_id = params[:user_id]
    @start_date = params[:start_date]
    @end_date = params[:end_date]
    @page = params[:page].to_i
    @page = 1 if @page <= 0

    calls = Call.all
    calls = calls.by_user(@user_id)
    calls = calls.between_dates(@start_date, @end_date)
    calls = calls.order(call_date: :desc, call_time: :desc)

    # KPI counters (computed on the filtered scope, not paginated)
    @total_count = calls.count
    answered_condition = "answered = TRUE OR (answered IS NULL AND COALESCE(duration, 0) > 0)"
    unanswered_condition = "answered = FALSE OR (answered IS NULL AND COALESCE(duration, 0) = 0)"
    @answered_count = calls.where(Arel.sql(answered_condition)).count
    @unanswered_count = calls.where(Arel.sql(unanswered_condition)).count
    @total_pages = (@total_count.to_f / PER_PAGE).ceil
    @calls = calls.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
  end

  def show
  end

  def new
    @call = Call.new(call_date: Date.current, call_time: Time.current)
  end

  def create
    @call = Call.new(call_params)
    if @call.save
      redirect_to @call, notice: "Llamada registrada correctamente"
    else
      flash.now[:alert] = "No se pudo guardar la llamada. Revisa los errores."
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @call.update(call_params)
      redirect_to @call, notice: "Llamada actualizada correctamente"
    else
      flash.now[:alert] = "No se pudo actualizar la llamada. Revisa los errores."
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_call
    @call = Call.find(params[:id])
  end

  def call_params
    params.require(:call).permit(:twilio_call_id, :call_date, :call_time, :user_id, :duration)
  end
end