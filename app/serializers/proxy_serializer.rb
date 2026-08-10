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

class ProxySerializer < ActiveModel::Serializer

  attributes :id, :name, :realm, :hostname, :port, :contact, :description, :comment, :use_individual_identities

  has_many :proxy_auth_keys, key: :proxy_identities, if: :include_proxy_auth_keys?

  def include_proxy_auth_keys?
    object.use_individual_identities
  end

end