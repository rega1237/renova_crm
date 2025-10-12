class AppointmentsController < ApplicationController
  before_action :set_client
  before_action :set_appointment, only: [ :edit, :update, :destroy ]

  def create
    # Parsear start_time en la zona horaria del cliente
    parsed_start_time = Time.find_zone(@client.timezone).parse(appointment_params[:start_time])

    @appointment = @client.appointments.new(appointment_params.except(:start_time).merge(start_time: parsed_start_time))
    @appointment.created_by = Current.user
    @appointment.end_time = @appointment.start_time + 1.hour if @appointment.start_time

    if @appointment.save
      CreateGoogleEventJob.perform_later(@appointment)
      flash.now[:notice] = "Cita agendada exitosamente. Se está sincronizando con Google Calendar."

      # Broadcast calendar update
      broadcast_calendar_update

      # --- Lógica de actualización de Cliente y Broadcast ---
      update_client_and_broadcast

    else
      # Re-render the form with errors
      render turbo_stream: turbo_stream.update(
        "appointment-form-container",
        partial: "appointments/form",
        locals: { client: @client, appointment: @appointment }
      ), status: :unprocessable_entity
    end
  end

  def edit
    render turbo_stream: turbo_stream.update(
      "appointment-form-container",
      partial: "appointments/form",
      locals: { client: @client, appointment: @appointment }
    )
  end

  def update
    # Parsear start_time en la zona horaria del cliente si se proporcionó
    if appointment_params[:start_time]
      parsed_start_time = Time.find_zone(@client.timezone).parse(appointment_params[:start_time])
      @appointment.assign_attributes(appointment_params.except(:start_time).merge(start_time: parsed_start_time))
      @appointment.end_time = @appointment.start_time + 1.hour
    else
      @appointment.assign_attributes(appointment_params)
    end

    if @appointment.save
      UpdateGoogleEventJob.perform_later(@appointment)
      flash.now[:notice] = "Cita actualizada exitosamente."

      # Broadcast calendar update
      broadcast_calendar_update

      streams = [
        turbo_stream.update("appointment-details-section", partial: "appointments/appointment_details", locals: { client: @client, appointment: @appointment }),
        turbo_stream.update("appointment-form-container", ""),
        turbo_stream.prepend("notifications-container", partial: "shared/flash_message", locals: { type: "notice", message: flash.now[:notice] })
      ]

      # Lógica para actualizar la vista del cliente y el broadcast
      update_client_and_broadcast_after_update(streams)

      render turbo_stream: streams
    else
      # Re-render the form with errors
      render turbo_stream: turbo_stream.update(
        "appointment-form-container",
        partial: "appointments/form",
        locals: { client: @client, appointment: @appointment }
      ), status: :unprocessable_entity
    end
  end

  def destroy
    @appointment.update(status: :canceled)
    DeleteGoogleEventJob.perform_later(@appointment)
    # Eliminar citas canceladas previas del cliente, dejando solo la última cancelada
    @client.appointments.canceled.where.not(id: @appointment.id).destroy_all

    # Incrementar contador de cancelaciones del cliente
    @client.increment!(:cancellations_count)

    # Crear nota automática indicando cancelación y usuario que cancela
    cancel_user_name = Current.user&.name || "Sistema"
    cancel_time_str = Time.current.strftime("%d/%m/%Y %H:%M")
    note_text = "Cita cancelada por #{cancel_user_name} el #{cancel_time_str}."
    note_text += " Título: #{@appointment.title}." if @appointment.title.present?
    note_text += " Fecha: #{@appointment.start_time.strftime('%d/%m/%Y %H:%M')}." if @appointment.start_time.present?
    note_text += " Dirección: #{@appointment.address}." if @appointment.address.present?
    @note = @client.notes.build(text: note_text)
    @note.created_by = Current.user if Current.user
    @note.save

    flash.now[:notice] = "Cita cancelada exitosamente."

    # Broadcast calendar update
    broadcast_calendar_update

    # Actualizar el estado del cliente a "reprogramar" y emitir broadcast al Sales Flow
    old_status = @client.status
    if @client.update(status: :reprogramar)
      client_html = ApplicationController.render(partial: "sales_flow/client_card", locals: { client: @client })
      ActionCable.server.broadcast("sales_flow_channel", {
        action: "client_moved",
        client_id: @client.id,
        client_name: @client.name,
        updated_by_name: Current.user&.name || "Sistema",
        old_status: old_status,
        new_status: "reprogramar",
        updated_at: @client.updated_status_at,
        client_html: client_html
      })
    end

    streams = [
      turbo_stream.update("appointment-details-section", partial: "appointments/empty"),
      turbo_stream.update("client_status_display", partial: "clients/field_display", locals: { client: @client, field: "status" }),
      turbo_stream.update("appointment-form-container", render_to_string(partial: "appointments/form", locals: { client: @client, appointment: (@client.appointments.find_by(status: "scheduled") || @client.appointments.new(seller_id: @client.assigned_seller_id, address: @client.address)) })),
      turbo_stream.prepend("notifications-container", partial: "shared/flash_message", locals: { type: "notice", message: flash.now[:notice] })
    ]

    # Prepend de la nueva nota a la lista de notas si se creó
    if @note&.persisted?
      streams << turbo_stream.prepend("notes-list", partial: "notes/note", locals: { note: @note })
    end

    render turbo_stream: streams
  end

  private

  def set_appointment
    @appointment = @client.appointments.find(params[:id])
  end

  def update_client_and_broadcast_after_update(streams)
    should_update_seller = @appointment.seller.present? && @client.assigned_seller != @appointment.seller
    should_update_address = @appointment.address.present? && @client.address.blank?

    if should_update_seller || should_update_address
      update_params = {}
      update_params[:assigned_seller] = @appointment.seller if should_update_seller
      update_params[:address] = @appointment.address if should_update_address

      if @client.update(update_params)
        if should_update_seller
          streams << turbo_stream.replace("assigned-seller-section", partial: "clients/assigned_seller_section", locals: { client: @client })
          streams << turbo_stream.update("client_assigned_seller_id_display", partial: "clients/field_display", locals: { client: @client, field: "assigned_seller_id" })
          client_html = ApplicationController.render(partial: "sales_flow/client_card", locals: { client: @client })
          ActionCable.server.broadcast("sales_flow_channel", { action: "assigned_seller_updated", client_id: @client.id, new_seller_name: @client.assigned_seller&.name || "Sin asignar", client_html: client_html })
        end

        if should_update_address
          streams << turbo_stream.update("client_address_display", partial: "clients/field_display", locals: { client: @client, field: "address" })
        end
      end
    end
  end

  def update_client_and_broadcast
    streams = [
      turbo_stream.update("appointment-details-section", partial: "appointments/appointment_details", locals: { client: @client, appointment: @appointment }),
      turbo_stream.update("appointment-form-container", ""),
      turbo_stream.prepend("notifications-container", partial: "shared/flash_message", locals: { type: "notice", message: flash.now[:notice] })
    ]

    should_update_seller = @appointment.seller.present? && @client.assigned_seller != @appointment.seller
    should_update_status = [ "lead", "no_contesto", "seguimiento", "no_cerro", "reprogramar" ].include?(@client.status)
    should_update_address = @appointment.address.present? && @client.address.blank?

    if should_update_seller || should_update_status || should_update_address
      old_status = @client.status
      update_params = {}
      update_params[:assigned_seller] = @appointment.seller if should_update_seller
      update_params[:status] = "cita_agendada" if should_update_status
      update_params[:address] = @appointment.address if should_update_address

      if @client.update(update_params)
        if should_update_seller
          streams << turbo_stream.replace("assigned-seller-section", partial: "clients/assigned_seller_section", locals: { client: @client })
          streams << turbo_stream.update("client_assigned_seller_id_display", partial: "clients/field_display", locals: { client: @client, field: "assigned_seller_id" })
          client_html = ApplicationController.render(partial: "sales_flow/client_card", locals: { client: @client })
          ActionCable.server.broadcast("sales_flow_channel", { action: "assigned_seller_updated", client_id: @client.id, new_seller_name: @client.assigned_seller&.name || "Sin asignar", client_html: client_html })
        end

        if should_update_status
          client_html = ApplicationController.render(partial: "sales_flow/client_card", locals: { client: @client })
          ActionCable.server.broadcast("sales_flow_channel", { action: "client_moved", client_id: @client.id, client_name: @client.name, updated_by_name: Current.user&.name || "Sistema", old_status: old_status, new_status: "cita_agendada", updated_at: @client.updated_status_at, client_html: client_html })
        end

        if should_update_address
          streams << turbo_stream.update("client_address_display", partial: "clients/field_display", locals: { client: @client, field: "address" })
        end
      end
    end

    render turbo_stream: streams
  end

  def set_client
    @client = Client.find(params[:client_id])
  end

  def appointment_params
    params.require(:appointment).permit(:title, :description, :start_time, :seller_id, :address)
  end

  def broadcast_calendar_update
    ActionCable.server.broadcast("calendar_updates", {
      action: "refresh_calendar",
      appointment_id: @appointment.id
    })
  end
end
