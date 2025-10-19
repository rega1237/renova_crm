class DashboardController < ApplicationController
  def index
    @states = State.ordered
    @telemarketers = User.telemarketing
    @sellers = Seller.order(:name)
  end

  def leads_metrics
    source = params[:source].presence
    state_id = params[:state_id].presence
    month = params[:month].presence
    day_param = params[:day].presence

    # Decide grouping and date bounds
    if day_param.present?
      # Always allow specific day (single bar)
      begin
        day_date = Date.parse(day_param)
        date_from = day_date.beginning_of_day
        date_to = day_date.end_of_day
      rescue ArgumentError
        render json: { categories: [], series: [] } and return
      end
      grouping = :day
    elsif month.present?
      # Month selected: single bar for whole month unless subrange provided
      begin
        month_date = Date.strptime(month, "%Y-%m")
      rescue ArgumentError
        render json: { categories: [], series: [] } and return
      end
      # Subfilters must be within month
      sub_from = params[:date_from].presence
      sub_to = params[:date_to].presence
      if sub_from.present? || sub_to.present?
        # Constrain to month range
        month_start = month_date.beginning_of_month
        month_end = month_date.end_of_month
        date_from = sub_from.present? ? [ Date.parse(sub_from), month_start ].max.beginning_of_day : month_start.beginning_of_day
        date_to = sub_to.present? ? [ Date.parse(sub_to), month_end ].min.end_of_day : month_end.end_of_day
      else
        date_from = month_date.beginning_of_month.beginning_of_day
        date_to = month_date.end_of_month.end_of_day
      end
      grouping = :month_single
    else
      # No month and no day: default monthly view (last 6 months)
      date_from = 6.months.ago.beginning_of_month
      date_to = Time.zone.now.end_of_month
      grouping = :months
    end

    # Base scope: all clients filtered by created_at
    scope = Client.all
    scope = scope.where(source: Client.sources[source]) if source && Client.sources.key?(source)
    scope = scope.where(state_id: state_id) if state_id
    scope = scope.where(created_at: date_from..date_to)

    case grouping
    when :day
      # Single day -> single category (the day)
      category = date_from.to_date.strftime("%Y-%m-%d")
      sources_keys = source && Client.sources.key?(source) ? [ source ] : Client.sources.keys
      series = sources_keys.map do |src|
        count = scope.where(source: Client.sources[src]).count
        { name: src.humanize, data: [ count ] }
      end
      render json: { categories: [ category ], series: series }
    when :month_single
      # Month (or subrange within month) -> single category (YYYY-MM)
      category = date_from.to_date.strftime("%Y-%m")
      sources_keys = source && Client.sources.key?(source) ? [ source ] : Client.sources.keys
      series = sources_keys.map do |src|
        count = scope.where(source: Client.sources[src]).count
        { name: src.humanize, data: [ count ] }
      end
      render json: { categories: [ category ], series: series }
    when :months
      # Default monthly view (last 6 months), source may be selected or not
      start_month = date_from.to_date.beginning_of_month
      end_month = date_to.to_date.beginning_of_month
      months_range = []
      current_month = start_month
      while current_month <= end_month
        months_range << current_month.strftime("%Y-%m")
        current_month = current_month.next_month
      end
      sources_keys = source && Client.sources.key?(source) ? [ source ] : Client.sources.keys
      series = sources_keys.map do |src|
        counts = scope.where(source: Client.sources[src]).group("DATE_TRUNC('month', created_at)").count
        counts_by_month_str = counts.transform_keys { |k| k.respond_to?(:strftime) ? k.strftime("%Y-%m") : k.to_s }
        data = months_range.map { |month_str| counts_by_month_str[month_str] || 0 }
        { name: src.humanize, data: data }
      end
      render json: { categories: months_range, series: series }
    end
  end

  def telemarketing_metrics
    source = params[:source].presence
    agent_id = params[:agent_id].presence
    month = params[:month].presence
    day_param = params[:day].presence

    # Decide grouping and date bounds (basado en citas)
    if day_param.present?
      begin
        day_date = Date.parse(day_param)
        date_from = day_date.beginning_of_day
        date_to = day_date.end_of_day
      rescue ArgumentError
        render json: { categories: [], series: [] } and return
      end
      grouping = :day
    elsif month.present?
      begin
        month_date = Date.strptime(month, "%Y-%m")
      rescue ArgumentError
        render json: { categories: [], series: [] } and return
      end
      sub_from = params[:date_from].presence
      sub_to = params[:date_to].presence
      if sub_from.present? || sub_to.present?
        month_start = month_date.beginning_of_month
        month_end = month_date.end_of_month
        date_from = sub_from.present? ? [ Date.parse(sub_from), month_start ].max.beginning_of_day : month_start.beginning_of_day
        date_to = sub_to.present? ? [ Date.parse(sub_to), month_end ].min.end_of_day : month_end.end_of_day
      else
        date_from = month_date.beginning_of_month.beginning_of_day
        date_to = month_date.end_of_month.end_of_day
      end
      grouping = :month_single
    else
      date_from = 6.months.ago.beginning_of_month
      date_to = Time.zone.now.end_of_month
      grouping = :months
    end

    # Base appointment scope: citas programadas creadas por telemarketing dentro del rango de fechas
    telemarketer_ids = User.telemarketing.select(:id)
    appointment_scope = Appointment.scheduled.where(start_time: date_from..date_to).where(created_by_id: telemarketer_ids)
    appointment_scope = appointment_scope.where(created_by_id: agent_id) if agent_id
    appointment_scope = appointment_scope.joins(:client)
    appointment_scope = appointment_scope.where(clients: { source: Client.sources[source] }) if source && Client.sources.key?(source)

    # Estados a graficar (excluye lead) y se atribuyen por la cita creada
    status_keys = [ "no_contesto", "seguimiento", "cita_agendada", "reprogramar", "vendido", "mal_credito", "no_cerro" ]

    case grouping
    when :day
      category = date_from.to_date.strftime("%Y-%m-%d")
      # Citas del día (por start_time)
      day_scope = appointment_scope.where(start_time: date_from..date_to)
      day_client_ids = day_scope.distinct.pluck(:client_id)

      series = status_keys.map do |st|
        if st == "cita_agendada"
          count = day_scope.count
        else
          count = Client.where(id: day_client_ids, status: Client.statuses[st]).count
        end
        { name: st.humanize, data: [ count ] }
      end

      render json: { categories: [ category ], series: series }
    when :month_single
      category = date_from.to_date.strftime("%Y-%m")
      # Citas del rango (subrango dentro del mes si aplica)
      month_client_ids = appointment_scope.distinct.pluck(:client_id)

      series = status_keys.map do |st|
        if st == "cita_agendada"
          count = appointment_scope.count
        else
          count = Client.where(id: month_client_ids, status: Client.statuses[st]).count
        end
        { name: st.humanize, data: [ count ] }
      end

      render json: { categories: [ category ], series: series }
    when :months
      start_month = date_from.to_date.beginning_of_month
      end_month = date_to.to_date.beginning_of_month
      months_range = []
      current_month = start_month
      while current_month <= end_month
        months_range << current_month.strftime("%Y-%m")
        current_month = current_month.next_month
      end

      series = status_keys.map do |st|
        if st == "cita_agendada"
          counts = appointment_scope.group("DATE_TRUNC('month', start_time)").count
          counts_by_month_str = counts.transform_keys { |k| k.respond_to?(:strftime) ? k.strftime("%Y-%m") : k.to_s }
          data = months_range.map { |m| counts_by_month_str[m] || 0 }
          { name: st.humanize, data: data }
        else
          data = months_range.map do |m|
            month_start = Date.strptime(m, "%Y-%m").beginning_of_month
            month_end = month_start.end_of_month
            month_scope = appointment_scope.where(start_time: month_start.beginning_of_day..month_end.end_of_day)
            month_client_ids = month_scope.distinct.pluck(:client_id)
            Client.where(id: month_client_ids, status: Client.statuses[st]).count
          end
          { name: st.humanize, data: data }
        end
      end

      render json: { categories: months_range, series: series }
    end
  end

  def sellers_metrics
    seller_id = params[:seller_id].presence
    status_param = params[:status].presence
    month = params[:month].presence
    day_param = params[:day].presence

    # Estados permitidos y la opción especial de citas agendadas
    allowed_status_keys = %w[vendido mal_credito no_cerro]
    selected_status_key = allowed_status_keys.include?(status_param) ? status_param : "vendido"

    # Decide grouping and date bounds
    if day_param.present?
      begin
        day_date = Date.parse(day_param)
        date_from = day_date.beginning_of_day
        date_to = day_date.end_of_day
      rescue ArgumentError
        render json: { categories: [], series: [], totals_by_status: {} } and return
      end
      grouping = :day
    elsif month.present?
      begin
        month_date = Date.strptime(month, "%Y-%m")
      rescue ArgumentError
        render json: { categories: [], series: [], totals_by_status: {} } and return
      end
      sub_from = params[:date_from].presence
      sub_to = params[:date_to].presence
      if sub_from.present? || sub_to.present?
        month_start = month_date.beginning_of_month
        month_end = month_date.end_of_month
        date_from = sub_from.present? ? [ Date.parse(sub_from), month_start ].max.beginning_of_day : month_start.beginning_of_day
        date_to = sub_to.present? ? [ Date.parse(sub_to), month_end ].min.end_of_day : month_end.end_of_day
      else
        date_from = month_date.beginning_of_month.beginning_of_day
        date_to = month_date.end_of_month.end_of_day
      end
      grouping = :month_single
    else
      date_from = 6.months.ago.beginning_of_month
      date_to = Time.zone.now.end_of_month
      grouping = :months
    end

    # Base scopes
    client_scope = Client.where(updated_status_at: date_from..date_to)
    client_scope = client_scope.where(assigned_seller_id: seller_id) if seller_id.present?

    appointment_scope = Appointment.scheduled.where(start_time: date_from..date_to)
    appointment_scope = appointment_scope.where(seller_id: seller_id) if seller_id.present?

    sellers = seller_id.present? ? Seller.where(id: seller_id) : Seller.order(:name)

    # Build categories and series
    categories = []
    series = []

    case grouping
    when :day
      categories = [ date_from.to_date.strftime("%Y-%m-%d") ]

      if status_param == "citas_agendadas"
        series = sellers.map do |seller|
          count = appointment_scope.where(seller_id: seller.id).count
          { name: seller.name, data: [ count ] }
        end
      elsif selected_status_key == "no_cerro"
        series = sellers.flat_map do |seller|
          base = client_scope.where(assigned_seller_id: seller.id, status: Client.statuses["no_cerro"])
          [
            { name: "#{seller.name} (no aplico)", data: [ base.where(reasons: "no_cerro_no_aplico").count ] },
            { name: "#{seller.name} (buen credito)", data: [ base.where(reasons: "no_cerro_buen_credito").count ] }
          ]
        end
      else
        series = sellers.map do |seller|
          count = client_scope.where(assigned_seller_id: seller.id, status: Client.statuses[selected_status_key]).count
          { name: seller.name, data: [ count ] }
        end
      end

    when :month_single
      categories = [ date_from.to_date.strftime("%Y-%m") ]

      if status_param == "citas_agendadas"
        series = sellers.map do |seller|
          count = appointment_scope.where(seller_id: seller.id).count
          { name: seller.name, data: [ count ] }
        end
      elsif selected_status_key == "no_cerro"
        series = sellers.flat_map do |seller|
          base = client_scope.where(assigned_seller_id: seller.id, status: Client.statuses["no_cerro"])
          [
            { name: "#{seller.name} (no aplico)", data: [ base.where(reasons: "no_cerro_no_aplico").count ] },
            { name: "#{seller.name} (buen credito)", data: [ base.where(reasons: "no_cerro_buen_credito").count ] }
          ]
        end
      else
        series = sellers.map do |seller|
          count = client_scope.where(assigned_seller_id: seller.id, status: Client.statuses[selected_status_key]).count
          { name: seller.name, data: [ count ] }
        end
      end

    when :months
      # Build months range
      start_month = date_from.to_date.beginning_of_month
      end_month = date_to.to_date.beginning_of_month
      months_range = []
      current_month = start_month
      while current_month <= end_month
        months_range << current_month.strftime("%Y-%m")
        current_month = current_month.next_month
      end
      categories = months_range

      if status_param == "citas_agendadas"
        series = sellers.map do |seller|
          counts = appointment_scope.where(seller_id: seller.id).group("DATE_TRUNC('month', start_time)").count
          counts_by_month_str = counts.transform_keys { |k| k.respond_to?(:strftime) ? k.strftime("%Y-%m") : k.to_s }
          data = months_range.map { |month_str| counts_by_month_str[month_str] || 0 }
          { name: seller.name, data: data }
        end
      elsif selected_status_key == "no_cerro"
        series = sellers.flat_map do |seller|
          base = client_scope.where(assigned_seller_id: seller.id, status: Client.statuses["no_cerro"])
          counts_no_aplico = base.where(reasons: "no_cerro_no_aplico").group("DATE_TRUNC('month', updated_status_at)").count
          counts_buen_credito = base.where(reasons: "no_cerro_buen_credito").group("DATE_TRUNC('month', updated_status_at)").count
          counts_no_aplico_by_month = counts_no_aplico.transform_keys { |k| k.respond_to?(:strftime) ? k.strftime("%Y-%m") : k.to_s }
          counts_buen_credito_by_month = counts_buen_credito.transform_keys { |k| k.respond_to?(:strftime) ? k.strftime("%Y-%m") : k.to_s }
          [
            { name: "#{seller.name} (no aplico)", data: months_range.map { |m| counts_no_aplico_by_month[m] || 0 } },
            { name: "#{seller.name} (buen credito)", data: months_range.map { |m| counts_buen_credito_by_month[m] || 0 } }
          ]
        end
      else
        series = sellers.map do |seller|
          counts = client_scope.where(assigned_seller_id: seller.id, status: Client.statuses[selected_status_key]).group("DATE_TRUNC('month', updated_status_at)").count
          counts_by_month_str = counts.transform_keys { |k| k.respond_to?(:strftime) ? k.strftime("%Y-%m") : k.to_s }
          data = months_range.map { |month_str| counts_by_month_str[month_str] || 0 }
          { name: seller.name, data: data }
        end
      end
    end

    # KPIs: Vendido, Mal credito, No cerro subdividido por razones y Citas agendadas
    totals_by_status = {}
    totals_by_status["Vendido"] = client_scope.where(status: Client.statuses["vendido"]).count
    totals_by_status["Mal credito"] = client_scope.where(status: Client.statuses["mal_credito"]).count
    totals_by_status["No cerro (no aplico)"] = client_scope.where(status: Client.statuses["no_cerro"], reasons: "no_cerro_no_aplico").count
    totals_by_status["No cerro (buen credito)"] = client_scope.where(status: Client.statuses["no_cerro"], reasons: "no_cerro_buen_credito").count
    totals_by_status["No cerro (no presento)"] = client_scope.where(status: Client.statuses["no_cerro"], reasons: "no_cerro_no_presento").count
    totals_by_status["Citas agendadas"] = appointment_scope.where.not(seller_id: nil).count

    # Datos para graficas de pie por vendedor
    pie_by_seller = sellers.map do |seller|
      seller_client_scope = client_scope.where(assigned_seller_id: seller.id)
      seller_appointment_scope = appointment_scope.where(seller_id: seller.id)
      {
        seller_id: seller.id,
        seller_name: seller.name,
        data: [
          { label: "Vendido", value: seller_client_scope.where(status: Client.statuses["vendido"]).count },
          { label: "Mal credito", value: seller_client_scope.where(status: Client.statuses["mal_credito"]).count },
          { label: "No cerro (no aplico)", value: seller_client_scope.where(status: Client.statuses["no_cerro"], reasons: "no_cerro_no_aplico").count },
          { label: "No cerro (buen credito)", value: seller_client_scope.where(status: Client.statuses["no_cerro"], reasons: "no_cerro_buen_credito").count },
          { label: "No cerro (no presento)", value: seller_client_scope.where(status: Client.statuses["no_cerro"], reasons: "no_cerro_no_presento").count },
          { label: "Citas agendadas", value: seller_appointment_scope.count }
        ]
      }
    end

    render json: { categories: categories, series: series, totals_by_status: totals_by_status, pie_by_seller: pie_by_seller }
  end
end
