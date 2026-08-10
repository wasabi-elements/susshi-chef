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
      class Gateways

        include ActiveModel::Validations

        attr_accessor :susshid_id, :config_version, :gateway, :partition_id, :partition_config, :proxies, :psk, :memcrypt_key

        validates :susshid_id, presence: true, length: { is: 4 }
        validates :partition_id, presence: true
        validates :gateway, presence: true
        validates :partition_config, presence: true
        validates :memcrypt_key, presence: true

        def initialize(call_params={})
          # Here we are receiving Body Params and no JSON, so the parameters are not wrapped into "gateway:"
          params = call_params.permit(:format, :SusshidId, :Psk, :MemcryptKey)
          @susshid_id      = params[:SusshidId]
          @psk             = params[:Psk]
          @memcrypt_key    = params[:MemcryptKey]
          @gateway         = SwiftGateway.find_by_identifier(@susshid_id)

          if @gateway
            @partition_id     = @gateway.partition_id
            partition         = SwiftPartition.find(@partition_id)
            @partition_config = partition.config_hash(@memcrypt_key)
            @config_version   = partition.version
            @proxies          = SwiftProxy.where(partition_id: @partition_id)
          end
        end
      end
    end
  end
end
