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

module ControllersSerializers

  class Gateways

    class Config < ActiveModel::Serializer

      attributes :ChefPsk, :ChefSpki, :ChefServerUrls, :SusshidId

      def ChefPsk
        object.sic_psk
      end

      def ChefSpki
        cert = OpenSSL::X509::Certificate.new(Preference.instance.sic_api_certificate.data)
        "sha256::#{Base64.urlsafe_encode64(OpenSSL::Digest::SHA256.digest(cert.public_key.to_der), padding: false)}"
      end

      def ChefServerUrls
        { default: [instance_options[:url]] }
      end

      def SusshidId
        object.susshid_identifier
      end

    end

  end
end
