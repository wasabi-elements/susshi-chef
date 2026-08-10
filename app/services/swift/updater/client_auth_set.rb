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

class Swift::Updater::ClientAuthSet
  class << self

    def swift_update(partition_id)
      client_auth_sets = []

      SwiftClientAuthSet.transaction do
        # Delete old entries for this partition
        SwiftClientAuthSet.where(partition_id: partition_id).delete_all
        # Insert new entries for this partition
        ::ClientAuthSet.where(partition_id: partition_id).each do |auth_set|
          client_auth_sets << SwiftClientAuthSet.new(id:                          auth_set.id,
                                                     partition_id:                partition_id,
                                                     publickey_auth_properties:   auth_set.publickey_auth_properties,
                                                     interactive_auth_properties: auth_set.interactive_auth_properties,
                                                     cache_properties:            auth_set.cache_properties,
                                                     preferred_auths:             auth_set.preferred_authentications,
                                                     required_auths:              auth_set.required_auths,
                                                     required_auths_cached:       auth_set.required_auths_cached)
        end
        SwiftClientAuthSet.import client_auth_sets, :validate => false
      end
    end

  end
end
