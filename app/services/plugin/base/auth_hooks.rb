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

module Plugin::Base::AuthHooks

  class Session
    class Context

      attr_accessor :gw_version, :params, :partition_id, :operation_mode, :susshi_user, :targets, :target_user, :target_host_name, :target_proxy_realm, :accesses, :access_ids, :access, :bastion, :response, :error, :auth_secret

      def initialize(params)
        @params = params
        @operation_mode = params.operation_mode
      end

      def hook_before_response_success
        true
      end

    end
  end

  class User

    class Interactive
      attr_accessor :params, :partition_id, :susshi_user, :client_auth_set

      def initialize(params)
        @params = params
      end

      def hook_before_response_success
        true
      end

      def hook_validate_interactive(user_input)
        @susshi_user.valid_interactive_input?(user_input: user_input, client_auth_set: client_auth_set)
      end
    end

  end

end