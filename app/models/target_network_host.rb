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

class TargetNetworkHost < Target

  #-- Datatypes

  alias_attribute :address, :name

  #-- Associations

  belongs_to :partition
  has_many :target_user_host_keys, -> { where.not(susshi_user_login_id: nil) },
           class_name:  'TargetHostKey',
           foreign_key: 'target_id', dependent: :destroy

  has_one :swift_network_host, foreign_key: 'target_id', dependent: :destroy

  #-- Scopes

  #-- Validations

  #-- Class Methods

  #-- Instance Methods

  def icon
    'fa-dot-circle'
  end

  def display_name_a
    [self.address, "(Network Host)"]
  end

  def display_type
    'Network Target'
  end

  def is_destroyable?
    false
  end

  def destroy_if_orphan
    return if target_user_host_keys.any?
    self.destroy
  end

end
