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

module Api::V1::Config
  class BastionsController < ApiController

    wrap_parameters :access, include: [:name, :description, :position, :position_after, :position_before, :active, :source_ip_members, :susshi_user_members, :proxy_members, :profile, :debug_level]

    private

    def api_allowed?
      super(:proxies)
    end

    def ee_write_feature? = Subscription.instance.feature_proxies?

    def sub_classes
      nil
    end

    def strong_params
      normalized_params.require(:access).permit(:name, :description, :position_after, :position_before, :active, :profile, :debug_level, source_ip_members: [], susshi_user_members: [], proxy_members: [] )
    end

    def strong_params_patch
      normalized_params.require(:access).permit(source_ip_members: [], susshi_user_members: [], proxy_members: [] )
    end

    def normalized_params
      _params = params
      case (pos = _params[:access].delete(:position))
        when nil, 'end', 'bottom'
          return _params
        when 'begin', 'top'
          pos = 1
      end
      _params[:access][:position_before] = pos
      _params
    end

    def rack_reducers
      super + [
          ->(active:) { where(active: active) },
          ->(description:) { where(api_query_search_string(:description, description)) },
          ->(source_ip_members_include:) { joins(:source_ips).where(api_query_search_string("source_ips.name", source_ip_members_include)) },
          ->(susshi_user_members_include:) { joins(:susshi_users).where(api_query_search_string("susshi_users.name", susshi_user_members_include)) },
          ->(proxy_members_include:) { joins(:proxies).where(api_query_search_string("proxies.name", proxy_members_include)) },
          ->(profile:) { joins(:bastion_profile).where(api_query_search_string("bastion_profiles.name", profile)) },
          ->(debug_level:) { where(debug_level: debug_level) }
      ]
    end

  end
end