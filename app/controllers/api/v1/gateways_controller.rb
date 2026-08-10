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
  class GatewaysController < ApiApplicationController

    respond_to :json

    before_action :validate_gateway_params

    #--- Called on firing up a susshid process or susshid receiving the remote command 'restart'
    def register
      @gw_version = gateway_version_uint32
      @renew_sic = false

      # Track fingerprint of gateway client certificates
      if @params&.gateway # @params.gateway --> SwiftGateway
        unless (fingerprint = request.headers["HTTP_X_SSL_CLIENT_FINGERPRINT"]).blank?
          gateway = Gateway.find_by_susshid_identifier(@params.gateway.identifier)

          if gateway && fingerprint != gateway.sic_certificate_fingerprint
              # Gateway must renew SIC certificate (and ca.pem), so we send it a hint to renew the SIC
              SystemEventLogger.logger.log(Logger::INFO, "SIC certificate on gateway must be updated. Process initiated.")
              @renew_sic = true
          end

          if gateway && fingerprint != gateway.ssl_client_fingerprint
            # Update fingerprint of gateway client certificate (SwiftGateway)
            @params.gateway.update_column(:ssl_client_fingerprint, fingerprint)

            # Update fingerprint of gateway client certificate (Gateway)
            gateway&.update_column(:ssl_client_fingerprint, fingerprint)

            # We now have the target fingerprint
            if fingerprint == gateway.sic_certificate_fingerprint
              SystemEventLogger.logger.log(Logger::INFO, "Gateway reported new SIC fingerprint. It now uses the new SIC certificate.", susshid_identifier: @params.gateway.identifier)
            end
          end
        end
      end

      respond_to do |format|
        format.json { render }
      end
    end

    #--- Initialize SIC
    def sic
      if Devise.secure_compare(@params.psk.to_s, @params.gateway.sic_psk.to_s)
        if (cert = SSL::Sic.create_sic_certificate_p12(@params.gateway, @params.memcrypt_key))
          # Record requesting IP address for further SIC communication, e.g. chef remote commands
          if @params.gateway.sic_host.blank?
            @params.gateway.update_column(:sic_host, request.remote_ip)
            Gateway.find_by(partition_id: @params.partition_id, susshid_identifier: @params.gateway.identifier)&.update_column(:sic_host, request.remote_ip)
          end

          respond_to do |format|
            format.json {
              render :json => {
                Ca: Base64.strict_encode64(Preference.first.sic_ca_certificate.data),
                Certificate: Base64.strict_encode64(cert.to_der)
              }
            }
          end

          SystemEventLogger.logger.log(Logger::INFO, "Gateway downloaded SIC certificate.", susshid_identifier: @params.gateway.identifier)
        else
          head :bad_request
        end
      else
        head :bad_request
      end
    end

    private

    def validate_gateway_params
      @params = Api::V1::Validate::Gateways.new(params)
      validate_params(@params)
    end

  end
end
