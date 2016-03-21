class ReportsController < ApplicationController
  before_filter :authenticate_user!

  def call_traffic_data_range
    authorize :report, :call_traffic_data_range?
    calls = Call.data_for_report(params[:date_range])
    formatted_report = Call.prepare_data_for_date_range(calls)
    render json: formatted_report, status: 200
  end

  def export_calls_traffic
    authorize :report, :export_calls_traffic?
    file_path = Call.export_calls_traffic(params[:export])
    send_file file_path, type: "application/xlsx"
  end

end
