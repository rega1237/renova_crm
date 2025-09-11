module ApplicationHelper
  def settings_section_active?
    controller_path.start_with?("settings/") || controller_path == "admin/users"
  end
end
