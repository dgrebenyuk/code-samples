class ReportPolicy < ApplicationPolicy

  def call_traffic_data_range?
    user && user.has_any_role?(:admin, :manager, :analyst)
  end

  def export_calls_traffic?
    user && user.has_any_role?(:admin, :manager, :analyst)
  end

end
