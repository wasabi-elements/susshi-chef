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
      class TargetHostkeys

        include ActiveModel::Validations

        attr_accessor :installation_id, :susshid_id, :partition_id, :proxy_id, :susshi_user, :target_host_name,
                      :target_hostkey, :target_hostkey_type, :target_ip_address, :target_port, :target_proxy_realm, :target_id

        validates :susshid_id, presence: true, length: { is: 4 }
        validates :susshi_user, presence: true
        validates :target_port, presence: true
        validates :target_hostkey, presence: true
        validates :target_hostkey_type, presence: true
        validates :target_id, presence: true

        def initialize(call_params={})
          params               = call_params.permit(:format, :InstallationId, :SusshidId, :SusshiUserName, :TargetHostKeyType,
                                                    :TargetId, :TargetHostKey, :TargetPort, :TargetProxyRealm, :TargetHostName, :TargetIpAddress)
          @installation_id     = params[:InstallationId]
          @susshid_id          = params[:SusshidId]
          @susshi_user         = params[:SusshiUserName]
          @target_proxy_realm  = params[:TargetProxyRealm]
          @target_hostkey_type = params[:TargetHostKeyType]
          @target_hostkey      = params[:TargetHostKey]
          @target_port         = params[:TargetPort] || 22
          @target_host_name    = params[:TargetHostName]
          @target_ip_address   = params[:TargetIpAddress]
          @target_id           = params[:TargetId]

          if @target_proxy_realm
            @proxy_id = SwiftProxy.find_by_realm(@target_proxy_realm).try(:id)
          end
        end

      end
    end
  end
end
