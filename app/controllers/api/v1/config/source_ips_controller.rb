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
  class SourceIpsController < ApiController

    wrap_parameters :source_ip, include: [:name, :description, :ip_address, :members, :memberships]

    private

    def sub_classes
      %w(nets groups)
    end

    def strong_params
      case @sub_class
        when 'groups'
          params.require(:source_ip).permit(:name, :description, members: [])
        when 'nets'
          params.require(:source_ip).permit(:name, :description, :ip_address, memberships: [])
      end
    end

    def strong_params_patch
      case @sub_class
        when 'groups'
          params.require(:source_ip).permit(members: [])
        when 'nets'
          params.require(:source_ip).permit(memberships: [])
      end
    end

    def rack_reducers
      super + [
          ->(read_only:) { where(system_int: read_only) },
          ->(description:) { where(api_query_search_string(:description, description)) },
          ->(ip_address:) { where(api_query_search_string(:ip_address, ip_address)) },
          ->(has_members:) { has_members.to_s == 'true' ? has_any_members : has_not_any_members },
          ->(has_memberships:) { has_memberships.to_s == 'true' ? has_any_memberships : has_not_any_memberships }
      ]
    end

  end
end