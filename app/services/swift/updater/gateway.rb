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

class Swift::Updater::Gateway
  class << self

    def swift_update(partition_id)
      gateways   = []
      install_id = Preference.first.installation_identifier

      SwiftGateway.transaction do
        # Delete old entries for this partition
        SwiftGateway.where(partition_id: partition_id).delete_all
        # Insert new entries for this partition
        ::Gateway.where(partition_id: partition_id).each do |gateway|
          gateways << SwiftGateway.new(id:                     gateway.id,
                                       partition_id:           partition_id,
                                       identifier:             gateway.susshid_identifier,
                                       name:                   gateway.name,
                                       installation_id:        install_id,
                                       listen_addresses:       gateway.listen_addresses,
                                       sic_host:               gateway.sic_host,
                                       sic_port:               gateway.sic_port,
                                       sic_psk:                gateway.sic_psk,
                                       sic_key:                gateway.sic_key.try(:data),
                                       sic_certificate:        gateway.sic_certificate.try(:data),
                                       ssl_client_fingerprint: gateway.ssl_client_fingerprint,
                                       syslog_key:             gateway.syslog_key.try(:data),
                                       syslog_certificate:     gateway.syslog_certificate.try(:data),
                                       sic_ssh_private_key:    gateway.sic_ssh_private_key.try(:data),
                                       sic_ssh_public_key:     (gateway.sic_ssh_public_key.data.split(' ')[0..1].join(' ') rescue nil),
                                       has_target_fusions:     Swift::Updater::TargetFusion.target_fusions.any?
          )
        end
        SwiftGateway.import gateways, :validate => false
      end
    end

  end
end
