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

module Api::V1
  class UsersController < ApiApplicationController

    respond_to :json

    before_action :validate_users_params

    def interactive

      @auth_hook = Plugin::AuthHooks::User::Interactive.new(@params)

      while true # Just to break out in case of error

        @auth_hook.partition_id = SwiftGateway.where(identifier: @params.susshid_id).pluck(:partition_id).first
        break unless @auth_hook.partition_id

        #-- Client Auth Set
        @auth_hook.client_auth_set = SwiftClientAuthSet.where(partition_id: @auth_hook.partition_id, id: @params.client_auth_set_id).first
        break unless @auth_hook.client_auth_set

        #-- Susshi User
        @auth_hook.susshi_user = SwiftSusshiUser.where(partition_id: @auth_hook.partition_id, name: @params.susshi_user_name).first
        break unless @auth_hook.susshi_user
        break unless @auth_hook.susshi_user.auth_passable?

        # Hook: Interactive user input validation
        unless @auth_hook.hook_validate_interactive(@params.susshi_user_input)
          @auth_hook.susshi_user.auth_failed!
          auth_locked = !@auth_hook.susshi_user.auth_passable?
          break
        end

        # Hook: Before Response success
        break unless @auth_hook.hook_before_response_success

        # Record successful authentication
        @auth_hook.susshi_user.auth_successful!

        head :ok, status: 200
        return

      end

      head auth_locked ? 406 : 404

    end

    #
    # This controller method is never called (no route exists so far), we do cache update via reporting instead
    # - We just keep it her in case we want to reuse code
    #

    def ip_cache

      while true # Just to break out in case of error

        partition_id = SwiftGateway.where(identifier: @params.susshid_id).pluck(:partition_id).first
        break unless partition_id

        #-- Client Auth Set
        cas = SwiftClientAuthSet.where(partition_id: partition_id, id: @params.client_auth_set_id).first
        break unless cas

        #-- Susshi User
        susshi_user = SwiftSusshiUser.where(partition_id: partition_id, name: @params.susshi_user_name).first
        break unless susshi_user

        #-- Client IP Address
        client_ip = IPAddress.parse(@params.client_ip) rescue nil
        break unless client_ip

        SwiftIpCaching.lookup(create:             true,
                              refresh:            cas.cache_refresh,
                              source_ip:          client_ip,
                              swift_susshi_user:  susshi_user,
                              client_auth_set_id: cas.id,
                              cache_idle_time:    cas.cache_idle_time,
                              max_cache_time:     cas.max_cache_time,
                              whitelist:          cas.cache_whitelist)

        head :ok, status: 200
        return

      end

      head 500
    end


    private

    def validate_users_params
      @params = Api::V1::Validate::Users.new(params)
      validate_params(@params)
    end

  end
end