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

class Swift::Updater::TargetUser
  class << self

    def swift_update(partition_id)
      users = []

      SwiftTargetUser.transaction do
        # Delete old entries for this partition
        SwiftTargetUser.where(partition_id: partition_id).delete_all
        # Insert new entries for this partition
        TargetUserLogin.where(partition_id: partition_id).each do |user|
          user_ids = user.target_user_group_ids
          user_ids << user.id
          access_ids = AccessesTargetUser.where(target_user_id: user_ids).pluck(:access_id).uniq
          if access_ids.any? or any_target_fusion_objects?(user.id)
            users << SwiftTargetUser.new(id: user.id,
                                         partition_id: partition_id,
                                         name: user.name,
                                         access_ids: access_ids)
          end
        end
        SwiftTargetUser.import users, :validate => false
      end
    end

    def any_target_fusion_objects?(target_user_login_id)
      Swift::Updater::TargetFusion.target_fusions.select{|fusion| fusion.target_user_id == target_user_login_id}.any?
    end

  end
end
