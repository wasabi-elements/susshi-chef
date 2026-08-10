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

class SystemEventsController < ApplicationController

  def index
    authorize :system_event, :index?

    @gateways = SwiftGateway.where(partition_id: current_user.partition.id).order(:name).pluck(:name, :identifier, :id).map {|g| ["#{g.first} [#{g.second}]", g.second]}
    @gateways << ["suSSHi Chef", "0000"]

    #-- Load session if no params set (required for assist queries)
    if params[:q].nil?
      params[:q] = session["#{controller_action}_query".to_sym] rescue {}
    end

    unless (params[:q][:assist][:daterange] rescue nil).blank?
      begin
        from, to = params[:q][:assist][:daterange].split('-').map(&:strip)
        params[:q][:devicereportedtime_gteq] = Time.strptime(from, "%m/%d/%Y")
        params[:q][:devicereportedtime_lteq] = Time.strptime(to, "%m/%d/%Y")+24.hours
        @daterange = "#{params[:q][:devicereportedtime_gteq].strftime("%m/%d/%Y")} - #{params[:q][:devicereportedtime_lteq].strftime("%m/%d/%Y")}"
      rescue
      end
    end

    @search_message = (params[:q][:message_cont] rescue nil)
    @search_session_id = (params[:q][:assist][:session_id_cont] rescue nil)
    @search_pid = (params[:q][:assist][:pid] rescue nil)

    @q = SystemEvent.ransack(params_query)
    ransack_default_sort(@q, :devicereportedtime, :desc)
    @system_events = @q.result

    unless @search_session_id.blank?
      @system_events = @system_events.where('message iLike ?', "%[%#{@search_session_id}%]%")
    end

    unless @search_pid.blank?
      @system_events = @system_events.where('syslogtag iLike ?', "susshid[#{@search_pid}]%")
    end

    @system_events = @system_events.page(params_page).per(params_per_page)
  end

end
