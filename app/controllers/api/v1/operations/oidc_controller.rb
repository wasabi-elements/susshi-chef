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
  class OidcController < Api::V1::OperationsController

    # No explicit wrap_parameters used because model is not directly storing information from params into model
    # see implicit in config/initializers/wrap_parameters.rb

    respond_to :json

    before_action :initialize_api_controller
    before_action :validate_oidc_params

    def validate
      ticket = SwiftAuthTicket.validate_ticket(secret: @params.secret, jwt: @params.jwt)

      unless ticket.blank?
        result = Susshid::RemoteControl.auth_grant(ticket)

        case result.dig("return")
          when "success"
            render status: :ok,
                   json:   { status: :success, message: "secret found, access granted" }
          when "failed"
            if result.dig("fail_reason") == "session not found"
              render status: :gone,
                     json:   { status: :session_gone, message: "session gone" }
            else
              render status: :unprocessable_entity,
                     json:   { status: :failed, message: "we had some serious issues talking to the gateway" }
            end
          else
            render status: :unprocessable_entity,
                   json:   { status: :failed, message: "we had some serious issues talking to the gateway" }
        end
      else
        render status: :not_found,
               json:   { status: :not_found, message: "secret not found" }
      end
    rescue
      render status: :bad_request,
             json:   { status: :bad_request, message: :bad_request }
    end

    def logout
      if SwiftAuthTicket.logout(jwt: @params.jwt)
        render status: :ok,
               json:   { status: :success, message: "logged out" }
      else
        render status: :unprocessable_entity,
               json:   { status: :failed, message: "logout failed" }
      end

    rescue
      render status: :bad_request,
             json:   { status: :bad_request, message: :bad_request }
    end

    private

    def api_allowed?
      case action_name.to_s
        when 'validate'
          @api_token.has_permission?('oidc', :read)
        when 'logout'
          @api_token.has_permission?('oidc', :destroy)
        else
          false
      end
    end

    private

    def validate_oidc_params
      @params = Api::V1::Validate::Operations::Oidc.new(params)
      validate_params(@params)
    end

  end
end