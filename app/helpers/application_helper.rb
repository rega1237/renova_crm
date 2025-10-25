module ApplicationHelper
  def settings_section_active?
    controller_path.start_with?("settings/") || controller_path == "admin/users"
  end

  def status_color(status)
    case status.to_s
    when "lead"
      "blue"
    when "no_contesto"
      "gray"
    when "seguimiento"
      "yellow"
    when "cita_agendada"
      "purple"
    when "reprogramar"
      "orange"
    when "vendido"
      "green"
    when "mal_credito", "no_cerro", "no_aplica_no_interesado"
      "red"
    else
      "gray"
    end
  end

  def status_badge_classes(status)
    case status.to_s
    when "lead"
      "bg-blue-100 text-blue-800"
    when "no_contesto"
      "bg-gray-100 text-gray-800"
    when "seguimiento"
      "bg-yellow-100 text-yellow-800"
    when "cita_agendada"
      "bg-purple-100 text-purple-800"
    when "reprogramar"
      "bg-orange-100 text-orange-800"
    when "vendido"
      "bg-green-100 text-green-800"
    when "mal_credito", "no_cerro", "no_aplica_no_interesado"
      "bg-red-100 text-red-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end

  def status_display_name(status)
    case status.to_s
    when "no_aplica_no_interesado"
      "No aplica / no interesado"
    else
      status.to_s.humanize
    end
  end

  def source_display_name(source)
    case source.to_s
    when "base_de_datos"
      "Base de datos"
    when "meta"
      "Meta"
    when "referencia"
      "Referencia"
    when "prospectacion"
      "Prospección"
    when "otro"
      "Otro"
    else
      source.to_s.humanize
    end
  end
end
