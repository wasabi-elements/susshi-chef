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
      class Sessions

        include ActiveModel::Validations

        attr_accessor :susshid_id, :susshi_uniq_id, :memcrypt_key, :partition_setting, :operation_mode, :gateway_setting,
                      :client_ip, :client_port, :login_string, :susshi_user, :target_user, :target_ips, :target_port,
                      :target_domains, :target_host_name, :target_proxy_realm, :shell_mode

        validates :susshid_id, presence: true, length: { is: 4 }
        validates :memcrypt_key, presence: true
        validates :client_ip, presence: true
        validates :susshi_user, presence: true

        def initialize(call_params = {})
          # Here we are receiving Body Params and no JSON, so the parameters are not wrapped into "session:"
          params = call_params.permit(:format, :SusshidId, :SusshiUniqId, :MemcryptKey, :OperationMode, :ClientIPAddress, :LoginString,
                                      :ClientPort, :SusshiUserName, :TargetHostName, :TargetProxyRealm, :TargetUserName, :TargetPort, TargetIPAddresses: [])

          @susshid_id         = params[:SusshidId]
          @susshi_uniq_id     = params[:SusshiUniqId]
          @memcrypt_key       = params[:MemcryptKey]
          @psk                = params[:Psk]
          @client_ip          = params[:ClientIPAddress]
          @client_port        = params[:ClientPort] || 0
          @target_proxy_realm = params[:TargetProxyRealm]
          @susshi_user        = params[:SusshiUserName]
          @target_user        = params[:TargetUserName]
          @target_ips         = params[:TargetIPAddresses] || []
          @target_port        = params[:TargetPort] || 22
          @target_host_name   = params[:TargetHostName]
          @login_string       = params[:LoginString]
          @target_domains     = []
          @operation_mode     = params[:OperationMode]
          @operation_mode     = target_user.blank? ? 'shell' : 'gateway' if @operation_mode.blank?

          unless @target_host_name.blank?
            unless (IPAddress(@target_host_name) rescue nil)
              @target_domains = TargetDomain.split_into_domains(@target_host_name)
            end
          end
        end

      end
    end
  end
end
