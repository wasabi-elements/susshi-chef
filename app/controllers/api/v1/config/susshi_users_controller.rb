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
  class SusshiUsersController < ApiController

    wrap_parameters :susshi_user, include: [:username, :description, :groupname, :name, :fullname, :email, :active, :members, :memberships, :susshi_user_keys, :totp_state, :totp_secret, :totp_activation_token]

    def update
      SusshiUser.transaction do
        super
      end
    end

    def index_flat_csv
      begin
        require 'csv'

        col_sep = params['col_sep'] || ','

        case @sub_class
          when 'groups'
            filename    = "susshi_users_groups_flat.csv"
            all_columns = [:groupname, :member]

            csv_file = CSV.generate(headers: true, col_sep: col_sep) do |csv|
              csv << all_columns
              SusshiUserGroup.where(partition: @partition).order(:name).left_outer_joins(:susshi_user_logins).select("susshi_users.name, susshi_user_logins_susshi_users.name as uname").distinct.each do |g|
                csv << [g.name, g.try(:uname)]
              end
            end
          when 'logins'
            filename    = "susshi_users_logins_flat.csv"
            all_columns = [:username, :membership]

            csv_file = CSV.generate(headers: true, col_sep: col_sep) do |csv|
              csv << all_columns
              SusshiUserLogin.where(partition: @partition).order(:name).left_outer_joins(:susshi_user_groups).select("susshi_users.name, susshi_user_groups_susshi_users.name as gname").distinct.each do |u|
                csv << [u.name, u.try(:gname)]
              end
            end
        end
        send_data csv_file, filename: filename, status: 200
      rescue
        respond_with_error_text(500)
      end
    end

    private

    def sub_classes
      %w(logins groups)
    end

    def strong_params
      case @sub_class
        when 'groups'
          params.require(:susshi_user).permit(:groupname, :description, :active, members: [])
        when 'logins'
          params.require(:susshi_user).permit(:username, :fullname, :email, :active, :totp_state, :totp_secret, :totp_activation_token, memberships: [], susshi_user_keys: [:title, :public_blob])
      end
    end

    def strong_params_patch
      case @sub_class
        when 'groups'
          params.require(:susshi_user).permit(members: [])
        when 'logins'
          params.require(:susshi_user).permit(memberships: [], susshi_user_keys: [:title, :public_blob])
      end
    end

    def rack_reducers
      super + [
          ->(active:) { where(active: active) },
          ->(email:) { where(api_query_search_string(:email, email)) },
          ->(fullname:) { where(api_query_search_string(:fullname, fullname)) },
          ->(groupname:) { where(api_query_search_string(:name, groupname)) },
          ->(username:) { where(api_query_search_string(:name, username)) },
          ->(has_members:) { has_members.to_s == 'true' ? has_any_members : has_not_any_members },
          ->(has_memberships:) { has_memberships.to_s == 'true' ? has_any_memberships : has_not_any_memberships },
          ->(has_susshi_user_keys:) { has_susshi_user_keys.to_s == 'true' ? has_any_keys : has_not_any_keys }
      ]
    end

  end
end