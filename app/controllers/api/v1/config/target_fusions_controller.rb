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
  class TargetFusionsController < ApiController

    wrap_parameters :target_fusion, include: [:groupname, :description, :target_user_name, :target_user_id, :target_name, :target_id, :members, :memberships]

    private

    def api_allowed?
      super(:targets)
    end

    def ee_write_feature? = Subscription.instance.feature_target_fusions?

    def sub_classes
      %w(links groups)
    end

    def strong_params
      case @sub_class
      when 'groups'
        params.require(:target_fusion).permit(:groupname, :description, members: [])
      when 'links'
        params.require(:target_fusion).permit(:description, :target_user_name, :target_user_id, :target_name, :target_id, memberships: [])
      end
    end

    def strong_params_patch
      case @sub_class
      when 'groups'
        params.require(:target_fusion).permit(members: [])
      when 'links'
        params.require(:target_fusion).permit(memberships: [])
      end
    end

    def rack_reducers
      super + [
          ->(groupname:) { where(api_query_search_string(:name, groupname)) },
          ->(target_user_id:) { where(target_user_id: target_user_id) },
          ->(target_user_name:) { joins(:target_user).where(api_query_search_string("target_users.name", target_user_name)) },
          ->(target_id:) { where(target_id: target_id) },
          ->(target_name:) { joins(:target).where(api_query_search_string("targets.name", target_name)) },
          ->(has_members:) { has_members.to_s == 'true' ? has_any_members : has_not_any_members },
          ->(has_memberships:) { has_memberships.to_s == 'true' ? has_any_memberships : has_not_any_memberships }
      ]
    end

  end
end