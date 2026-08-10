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

class Swift::Updater::Profile
  class << self

    def swift_update(partition_id)
      profiles = []

      SwiftProfile.transaction do
        # Delete old entries for this partition
        SwiftProfile.where(partition_id: partition_id).delete_all
        # Insert new entries for this partition
        ::Profile.where(partition_id: partition_id).each do |profile|
          profiles << SwiftProfile.new(id:           profile.id,
                                       partition_id: partition_id,
                                       config:       profile.swift_config_hash)
        end
        SwiftProfile.import profiles, :validate => false
      end
    end

  end
end
