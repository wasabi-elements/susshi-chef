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

class Swift::Updater::TargetFusion

  @target_fusions = []

  class << self

    attr_accessor :target_fusions

    def swift_update(partition_id)
      @target_fusions = []

      if Subscription.instance.feature_target_fusions?
        TargetFusion.transaction do
          # Delete old entries for this partition
          SwiftTargetFusion.where(partition_id: partition_id).delete_all
          # Insert new entries for this partition
          TargetFusionLink.where(partition_id: partition_id).each do |fusion|

            fusion_ids = fusion.target_fusion_group_ids
            fusion_ids << fusion.id

            access_ids = AccessesTargetFusion.where(target_fusion_id: fusion_ids).pluck(:access_id).uniq
            if access_ids.any?
              @target_fusions << SwiftTargetFusion.new(partition_id:   partition_id,
                                                       target_id:      fusion.target_id,
                                                       target_user_id: fusion.target_user_id,
                                                       access_ids:     access_ids)
            end
          end
          SwiftTargetFusion.import @target_fusions, :validate => false
        end
      end
    end

  end
end
