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

class Swift::Updater::TargetUserRegex
  class << self

    def swift_update(partition_id)
      users = []

      SwiftTargetUserRegex.transaction do
        # Delete old entries for this partition
        SwiftTargetUserRegex.where(partition_id: partition_id).delete_all
        # Insert new entries for this partition
        ActiveRecord::Base.connection.execute(sql_string(partition_id)).each do |record|
          users << SwiftTargetUserRegex.new(access_id: record['id'].to_i,
                                            partition_id: partition_id,
                                            regexes: (JSON.parse(record['regexes']) + JSON.parse(record['regexes_group'])).compact.uniq )
        end
        SwiftTargetUserRegex.import users, :validate => false
      end
    end

    def sql_string(partition_id)
      <<SQL
          SELECT accesses.id, json_agg(direct.regex_effective) as regexes, json_agg(indirect.regex_effective) as regexes_group
          FROM "accesses"
          INNER JOIN "accesses_target_users" ON "accesses_target_users"."access_id" = "accesses"."id"
          INNER JOIN "target_users" "direct" ON "direct"."id" = "accesses_target_users"."target_user_id"
          LEFT OUTER JOIN "target_user_memberships" ON "target_user_memberships"."target_user_group_id" = "direct"."id"
          LEFT OUTER JOIN "target_users" "indirect" ON "indirect"."id" = "target_user_memberships"."target_user_id"
          WHERE (
           (accesses.active = true)
           AND
           (accesses.partition_id = #{partition_id})
           AND (
           (
            (direct.type = 'TargetUserRegex')
           ) OR (
            (direct.type = 'TargetUserGroup')
            AND (target_user_memberships.target_user_id = indirect.id)
            AND (indirect.type = 'TargetUserRegex')
           ))) GROUP BY accesses.id
SQL
    end

  end
end
