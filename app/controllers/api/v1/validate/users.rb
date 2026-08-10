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

module Api
  module V1
    module Validate
      class Users

        include ActiveModel::Validations

        attr_accessor :installation_id, :susshid_id, :partition_id, :client_ip, :susshi_user_name, :susshi_user_input, :client_auth_set_id

        validates :susshid_id, presence: true, length: { is: 4 }
        validates :susshi_user_name, presence: true
        validates :client_auth_set_id, presence: true

        def initialize(call_params={})
          params = call_params.permit(:format, :InstallationId, :LoginString, :SusshidId, :SusshiUserName, :SusshiUserInput, :ClientIPAddress, :ClientAuthSetId)
          @installation_id    = params[:InstallationId]
          @susshid_id         = params[:SusshidId]
          @susshi_user_name   = params[:SusshiUserName]
          @susshi_user_input  = params[:SusshiUserInput]
          @client_ip          = params[:ClientIPAddress]
          @client_auth_set_id = params[:ClientAuthSetId]
        end

      end
    end
  end
end
