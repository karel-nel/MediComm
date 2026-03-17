module Admin
  class SidebarComponent < ViewComponent::Base
    NavItem = Struct.new(:label, :path, :prefix, keyword_init: true)

    def initialize(current_path:, practice:)
      @current_path = current_path
      @practice = practice
    end

    def nav_items
      @nav_items ||= [
        NavItem.new(label: "Overview", path: helpers.admin_root_path, prefix: "/admin"),
        NavItem.new(label: "Sessions", path: helpers.admin_sessions_path, prefix: "/admin/sessions"),
        NavItem.new(label: "Flows", path: helpers.admin_flows_path, prefix: "/admin/flows"),
        NavItem.new(label: "WhatsApp", path: helpers.admin_whatsapp_path, prefix: "/admin/whatsapp"),
        NavItem.new(label: "Files", path: helpers.admin_files_path, prefix: "/admin/files"),
        NavItem.new(label: "Team", path: helpers.admin_team_members_path, prefix: "/admin/team_members"),
        NavItem.new(label: "Billing", path: helpers.admin_billing_path, prefix: "/admin/billing"),
        NavItem.new(label: "Settings", path: helpers.admin_settings_path, prefix: "/admin/settings")
      ]
    end

    def active?(item)
      return true if @current_path == item.path
      return true if item.path == helpers.admin_root_path && @current_path == helpers.root_path
      return false if item.path == helpers.admin_root_path

      @current_path.start_with?(item.prefix)
    end

    def practice_name
      @practice&.name.presence || "Practice"
    end
  end
end
