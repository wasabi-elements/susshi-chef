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

class Swift::Updater::TargetNetworkHost
  class << self

    def swift_update(partition_id)
      network_hosts = []

      SwiftNetworkHost.transaction do
        # Delete old entries for this partition
        SwiftNetworkHost.where(partition_id: partition_id).delete_all
        # Insert new entries for this partition
        TargetNetworkHost.includes(:proxy, target_user_host_keys: [:susshi_user_login]).where(partition_id: partition_id).each do |target|
          user_keys = Swift::Updater::Target.target_user_host_keys(target)
          network_hosts << SwiftNetworkHost.new(partition_id: partition_id,
                                                id:           target.id,
                                                target_id:    target.id,
                                                address:      target.address,
                                                user_keys:    user_keys,
                                                proxy_realm:  target.proxy.try(:realm))
        end
        SwiftNetworkHost.import network_hosts, :validate => false
      end
    end

  end
end
