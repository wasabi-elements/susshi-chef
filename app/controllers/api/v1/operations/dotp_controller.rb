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

module Api::V1::Operations
  class DotpController < Api::V1::OperationsController

    respond_to :json

    before_action :initialize_api_controller

    def validate

      while true # Just to break out in case of error

        unless params[:target_username]
          respond_with_error_text( :bad_request, 'target_username missing')
          return
        end

        unless params[:target_password]
          respond_with_error_text( :bad_request, 'target_password missing')
          return
        end

        if SwiftDotpTicket.lookup_ticket(partition_id:    @partition.id,
                                         target_user:     params[:target_username],
                                         target_password: params[:target_password],
                                         target_identity: params[:target_identity])
          head :ok, status: 200
          return
        else
          break
        end

      end

      head 404

    end


    private

    def api_allowed?
      @api_token.has_permission?('dotp', :read)
    end

  end
end