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

class ProxyAuthKey < PartitionKey
  encrypts :private_blob

  #-- Associations

  #-- Callbacks
  before_create :before_create_create_key

  #-- Validations

  #-- Class methods
  class << self
    def reorder(ids)
      objects = PartitionAuthKey.where(id: ids).order(order: :asc)
      orders = objects.pluck(:order)
      ids = ids & objects.pluck(:id)
      unless orders.count < 2
        ids.each_with_index do |id, index|
          PartitionAuthKey.find_by_id(id).update(order: orders[index])
        end
      end
    end
  end

  #-- Instance methods
  def icon
    'fa-id-card'
  end

  private

  def before_create_create_key
    if self.public_blob.blank?
      self.public_blob, self.private_blob, self.fingerprint =
        SshKey.generate_key_data(key_type, bits, "suSSHi2 Authentication Key")
    end
  end
end