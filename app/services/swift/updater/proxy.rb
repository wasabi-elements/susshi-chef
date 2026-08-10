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

class Swift::Updater::Proxy
  class << self

    def swift_update(partition_id)
      proxies    = []

      if Subscription.instance.feature_proxies?
        SwiftProxy.transaction do
          # Delete old entries for this partition
          SwiftProxy.where(partition_id: partition_id).delete_all
          # Insert new entries for this partition
          ::Proxy.where(partition_id: partition_id).each do |proxy|
            bastion_ids = BastionsProxy.where(proxy_id: proxy.id).pluck(:bastion_id)
            proxies << SwiftProxy.new(id:           proxy.id,
                                      partition_id: partition_id,
                                      realm:        proxy.realm,
                                      hostname:     proxy.hostname,
                                      port:         proxy.port,
                                      identities:   proxy_auth_keys(proxy),
                                      bastion_ids:  bastion_ids
            )
          end
          SwiftProxy.import proxies, :validate => false
        end
      end
    end

    def proxy_auth_keys(proxy)
      return nil unless proxy.proxy_auth_keys.any?
      proxy.proxy_auth_keys.map {|key| key.swift_config_hash }
    end

  end
end
