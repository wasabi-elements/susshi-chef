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

class Swift::Updater::Access
  class << self

    def swift_update(partition_id)
      accesses = []

      SwiftAccess.transaction do
        # Delete old entries for this partition
        SwiftAccess.where(partition_id: partition_id).delete_all
        # Insert new entries for this partition
        ActiveRecord::Base.connection.execute(sql_string(partition_id)).each do |record|
          accesses << SwiftAccess.new(id: record['id'].to_i,
                                      partition_id: partition_id,
                                      position: record['position'].to_i,
                                      profile_id: record['profile_id'].to_i,
                                      source_ids: (JSON.parse(record['direct_source_ip_ids']) + JSON.parse(record['indirect_source_ip_ids'])).compact.uniq,
                                      debug_level: record['debug_level'])
        end
        SwiftAccess.import accesses, :validate => false
      end
    end

    def sql_string(partition_id)
      <<SQL
          SELECT accesses.id, accesses.profile_id, accesses.position, accesses.debug_level, json_agg(direct.id) AS direct_source_ip_ids, json_agg(indirect.id) AS indirect_source_ip_ids
            FROM "accesses"
            INNER JOIN "accesses_source_ips" ON "accesses_source_ips"."access_id" = "accesses"."id"
            INNER JOIN "source_ips" "direct" ON "direct"."id" = "accesses_source_ips"."source_ip_id"
            LEFT OUTER JOIN "source_ip_memberships" ON "source_ip_memberships"."source_ip_group_id" = "direct"."id"
            LEFT OUTER JOIN "source_ips" "indirect" ON "indirect"."id" = "source_ip_memberships"."source_ip_net_id"
            WHERE (
             (accesses.active = true)
             AND
             (accesses.partition_id = #{partition_id})
             AND ((
             (direct.type = 'SourceIpNet')
            ) OR (
              (direct.type = 'SourceIpGroup')
              AND (source_ip_memberships.source_ip_net_id = indirect.id)
              AND (indirect.type = 'SourceIpNet')
            ))) GROUP BY accesses.id
SQL
    end

  end
end
