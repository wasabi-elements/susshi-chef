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

class DashboardsController < ApplicationController

  def overview
    @chart_data = chart_data
    @subscription = Subscription.instance
  end

  def api_manual
    render :file => 'public/api_manual.html', layout: false
  end

  def pm_collection
    send_file "#{Rails.root}/public/pm_collection.json", type: :json, filename: 'susshi_chef_api_pm_collection.json'
  end

  def pm_environment
    send_file "#{Rails.root}/public/pm_environment.json", type: :json, filename: 'susshi_chef_environment.json'
  end

  private

  def chart_data
    {
      total:       Access.count_by_time("true"),
      finished:    Access.count_by_time("session_state = 'finished'"),
      active:      Access.count_by_time("(session_state = 'active') OR (session_state = 'new')"),
      failed:      Access.count_by_time("session_state = 'failed'"),
      denied:      Access.count_by_time("session_state = 'denied'"),
      total_w:     Access.count_by_time_7days("true"),
      finished_w:  Access.count_by_time_7days("session_state = 'finished'"),
      active_w:    Access.count_by_time_7days("(session_state = 'active') OR (session_state = 'new')"),
      failed_w:    Access.count_by_time_7days("session_state = 'failed'"),
      denied_w:    Access.count_by_time_7days("session_state = 'denied'"),
      ap_active:   Access.count_for_partition(true),
      ap_inactive: Access.count_for_partition(false),
      gw_logins:   SusshiUserLogin.count_for_partition,
      gw_groups:   SusshiUserGroup.count_for_partition,
      tu_logins:   TargetUserLogin.count_for_partition,
      tu_regex:    TargetUserRegex.count_for_partition,
      tu_mapping:  TargetUserMapping.count_for_partition,
      tu_groups:   TargetUserGroup.count_for_partition,
      t_statics:   TargetHost.count_for_partition,
      t_dynamics:  TargetDynamic.count_for_partition,
      t_domains:   TargetDomain.count_for_partition,
      t_networks:  TargetNetwork.count_for_partition,
      t_groups:    TargetGroup.count_for_partition
    }
  end

  def subscription_params
    params.require(:subscription).permit(:subscription_key)
  end

end