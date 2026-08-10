# Copyright (C) 2026 Wasabi Elements GmbH
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

class SessionReportsController < ApplicationController


  before_action :find_and_authorize, only: [:show, :terminate]


  def index
    authorize :session_report, :index?

    SessionReport.process_crashed_reports(current_user.partition.id)

    #-- Load session if no params set (required for assist queries)
    if params[:q].nil?
      params[:q] = session["#{controller_action}_query".to_sym] rescue {}
    end

    unless (params[:q][:assist][:daterange] rescue nil).blank?
      from, to = params[:q][:assist][:daterange].split('-').map(&:strip)

    end

    unless (params[:q][:assist][:daterange] rescue nil).blank?
      begin
        from, to = params[:q][:assist][:daterange].split('-').map(&:strip)
        params[:q][:session_start_gteq] = Date.strptime(from, "%m/%d/%Y")
        params[:q][:session_start_lteq] = Time.strptime(to, "%m/%d/%Y")+24.hours
        @daterange = "#{params[:q][:session_start_gteq].strftime("%m/%d/%Y")} - #{params[:q][:session_start_lteq].strftime("%m/%d/%Y")}"
      rescue
      end
    end

    @q = policy_scope(SessionReport).where(partition_id: current_user.partition.id).ransack(params_query)
    ransack_default_sort(@q, :susshi_uniqid, :desc)
    @session_reports = @q.result.page(params_page).per(params_per_page)
    @period = SwiftPartition.find_by_partition_id(current_user.partition.id).config['ReportPeriod'] rescue nil
    @period ||= PartitionSetting.find_by_partition_id(current_user.partition.id).ReportPeriod || 900
    @has_proxy = Subscription.instance.feature_proxies?
  end

  def show
    @title = "Details of session '#{@session_report.susshi_uniqid}'"
    @period = SwiftPartition.find_by_partition_id(current_user.partition.id).config['ReportPeriod'] rescue nil
    @period ||= PartitionSetting.find_by_partition_id(current_user.partition.id).ReportPeriod || 900
    @system_events = SystemEvent.where('message iLike ?', "%[%#{@session_report.susshi_uniqid}%]%")
    respond_to do |format|
      format.html # show.html.erb
    end
  end

  def terminate
    authorize :session_report, :terminate?

    result = Susshid::RemoteControl.terminate(@session_report)['return'] rescue 'failed'

    if result == 'success'
      redirect_to session_reports_path, :flash => { :success => 'Session was successfully terminated.' }
    else
      redirect_to session_reports_path, :flash => { :destroy => 'Failed to terminate session.' }
    end
  end

  private

  def find_and_authorize(id = params[:id])
    @session_report = SessionReport.readonly(false).find(id)
    authorize @session_report
  end

end
