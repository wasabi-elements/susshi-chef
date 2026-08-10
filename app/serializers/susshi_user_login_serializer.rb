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

class SusshiUserLoginSerializer < ActiveModel::Serializer

  attributes :id, :username, :fullname, :email, :active, :memberships,
             :first_use_at, :last_use_at, :use_count

  attribute :totp_state,            if: :include_totp_state?
  attribute :totp_uri,              if: :include_totp_uri?
  attribute :totp_activation_token, if: :include_totp_activation_token?

  has_many :susshi_user_keys

  def include_totp_state?
    include_totp?
  end

  def include_totp_uri?
    include_totp? && object.totp_state == 'active'
  end

  def include_totp_activation_token?
    include_totp? && object.totp_state == 'activation_pending'
  end

  def include_totp?
    @instance_options[:api_token].has_permission?(:susshi_users, :totp)
  end

end