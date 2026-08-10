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
  class Proxies
    class Config < ActiveModel::Serializer
      attributes :InstallationId, :ListenAddresses, :GatewayAddresses, :HostKeys, :GatewayIdentityKeys

      def InstallationId
        Preference.first.installation_identifier
      end

      def ListenAddresses
        ["0.0.0.0:#{object.port}", "[::]:#{object.port}"]
      end

      def GatewayAddresses
        object.partition.partition_setting.GatewayAddresses
      end

      def HostKeys
        keys = PartitionHostKey.where(partition: object.partition, key_type: %w(ssh-rsa ssh-ed25519)).order(key_type: :desc)
        keys.collect do |key|
          ControllersSerializers::Proxies::HostKey.new(key).to_h
        end
      end

      def GatewayIdentityKeys
        PartitionAuthKey.where(partition: object.partition).collect do |key|
          ControllersSerializers::Proxies::AuthKey.new(key).to_h
        end
      end
    end

    class HostKey < ActiveModel::Serializer
      attributes :key_type, :fingerprint, :key_blob

      def key_blob
        object.private_blob
      end
    end

    class AuthKey < ActiveModel::Serializer
      attributes :key_type, :fingerprint, :public_blob

      def public_blob
        object.public_blob_base64
      end
    end
  end
end
