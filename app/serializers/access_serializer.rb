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

class AccessSerializer < ActiveModel::Serializer

  attributes :id, :name, :description, :active, :position, :source_ip_members, :susshi_user_members, :target_user_members, :target_members, :debug_level,
             :first_use_at, :last_use_at, :use_count

  attribute :target_fusion_members, if: :include_target_fusion_members?

  attribute :access_profile

  def include_target_fusion_members?
    Subscription.instance.feature_target_fusions?
  end

end