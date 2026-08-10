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
  class TargetUsersController < ApiController

    wrap_parameters :target_user, include: [:name, :username, :groupname, :description, :regex, :translate, :regex_target_user, :members, :memberships]

    private

    def sub_classes
      %w(logins mappings regexes groups)
    end

    def strong_params
      case @sub_class
        when 'groups'
          params.require(:target_user).permit(:groupname, :description, members: [])
        when 'logins'
          params.require(:target_user).permit(:username, :description, memberships: [])
        when 'mappings'
          params.require(:target_user).permit(:name, :regex, :translate, :regex_target_user, :description, memberships: [])
        when 'regexes'
          params.require(:target_user).permit(:name, :regex, :description, memberships: [])
      end
    end

    def strong_params_patch
      case @sub_class
        when 'groups'
          params.require(:target_user).permit(members: [])
        when 'logins', 'mappings', 'regexes'
          params.require(:target_user).permit(memberships: [])
      end
    end

    def rack_reducers
      super + [
          ->(username:) { where(api_query_search_string(:name, username)) },
          ->(groupname:) { where(api_query_search_string(:name, groupname)) },
          ->(description:) { where(api_query_search_string(:description, description)) },
          ->(has_members:) { has_members.to_s == 'true' ? has_any_members : has_not_any_members },
          ->(has_memberships:) { has_memberships.to_s == 'true' ? has_any_memberships : has_not_any_memberships }
      ]
    end

  end
end