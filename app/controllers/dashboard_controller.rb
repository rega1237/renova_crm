class DashboardController < ApplicationController
  def index
    @states = State.ordered
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
        date_from = sub_from.present? ? [Date.parse(sub_from), month_start].max.beginning_of_day : month_start.beginning_of_day
        date_to = sub_to.present? ? [Date.parse(sub_to), month_end].min.end_of_day : month_end.end_of_day
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
      sources_keys = source && Client.sources.key?(source) ? [source] : Client.sources.keys
      series = sources_keys.map do |src|
        count = scope.where(source: Client.sources[src]).count
        { name: src.humanize, data: [count] }
      end
      render json: { categories: [category], series: series }
    when :month_single
      # Month (or subrange within month) -> single category (YYYY-MM)
      category = date_from.to_date.strftime("%Y-%m")
      sources_keys = source && Client.sources.key?(source) ? [source] : Client.sources.keys
      series = sources_keys.map do |src|
        count = scope.where(source: Client.sources[src]).count
        { name: src.humanize, data: [count] }
      end
      render json: { categories: [category], series: series }
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
      sources_keys = source && Client.sources.key?(source) ? [source] : Client.sources.keys
      series = sources_keys.map do |src|
        counts = scope.where(source: Client.sources[src]).group("DATE_TRUNC('month', created_at)").count
        counts_by_month_str = counts.transform_keys { |k| k.respond_to?(:strftime) ? k.strftime("%Y-%m") : k.to_s }
        data = months_range.map { |month_str| counts_by_month_str[month_str] || 0 }
        { name: src.humanize, data: data }
      end
      render json: { categories: months_range, series: series }
    end
  end
end
