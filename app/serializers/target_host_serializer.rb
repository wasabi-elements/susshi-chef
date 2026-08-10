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

class TargetHostSerializer < ActiveModel::Serializer

  attributes :id, :hostname, :description, :active, :memberships
  attribute :proxy_realm, if: :include_proxy_realm?

  has_many :target_sockets, key: 'sockets'
  has_many :target_host_keys

  def include_proxy_realm?
    true if object.proxy_id != nil
  end

end