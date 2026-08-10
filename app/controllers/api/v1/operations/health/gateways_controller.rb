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

module Api::V1::Operations::Health
  class GatewaysController < Api::V1::OperationsController

    respond_to :json
    before_action :initialize_api_controller

    def index
      gateways = Gateway.where(partition_id: @partition.id) rescue nil
      if gateways
        result = gateways.map do |gateway|
          gateway.status_gateway(gateway.id)
        end
        render json: result
      end
    end

    def show
      gateway = Gateway.where(partition_id: @partition.id).where('id = ? OR name = ?', @id, @identity).limit(1).first
      if gateway
        render json: gateway.status_gateway(gateway.id)
      else
        respond_with_error_text( :not_found, 'not found.')
      end
    end

    private

    def api_allowed?
      case action_name.to_s
        when 'index', 'show'
          @api_token.has_permission?('healths', :read)
        else
          false
      end
    end

  end
end
