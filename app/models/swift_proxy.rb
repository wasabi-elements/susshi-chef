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

class SwiftProxy < Swift

  encrypts :identities

  belongs_to :partition

  #
  # Replace SSH private keys with memcrypt key encrypted SSH private keys
  #
  # The SSH private keys are stored in DB with ActiveRecord encryption
  # On the gateways they should be hold in memory encrypted with dynamic memcrypt key
  #
  def identities_encrypted(memcrypt_key)
    identities.map do |identity|
      identity["private_blob"] = Swift.ssh_keygen(identity["private_blob"], memcrypt_key)
      identity
    end
  end

end
