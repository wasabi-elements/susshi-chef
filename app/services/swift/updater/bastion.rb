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

class Swift::Updater::Bastion
  class << self

    def swift_update(partition_id)
      bastions = []

      if Subscription.instance.feature_proxies?
        SwiftBastion.transaction do
          # Delete old entries for this partition
          SwiftBastion.where(partition_id: partition_id).delete_all
          # Insert new entries for this partition
          ActiveRecord::Base.connection.execute(sql_string(partition_id)).each do |record|
            bastions << SwiftBastion.new(id: record['id'].to_i,
                                        partition_id: partition_id,
                                        position: record['position'].to_i,
                                        bastion_profile_id: record['bastion_profile_id'].to_i,
                                        source_ids: (JSON.parse(record['direct_source_ip_ids']) + JSON.parse(record['indirect_source_ip_ids'])).compact.uniq,
                                        debug_level: record['debug_level'])
          end
          SwiftBastion.import bastions, :validate => false
        end
      end
    end

    def sql_string(partition_id)
      <<SQL
          SELECT bastions.id, bastions.bastion_profile_id, bastions.position, bastions.debug_level, json_agg(direct.id) AS direct_source_ip_ids, json_agg(indirect.id) AS indirect_source_ip_ids
            FROM "bastions"
            INNER JOIN "bastions_source_ips" ON "bastions_source_ips"."bastion_id" = "bastions"."id"
            INNER JOIN "source_ips" "direct" ON "direct"."id" = "bastions_source_ips"."source_ip_id"
            LEFT OUTER JOIN "source_ip_memberships" ON "source_ip_memberships"."source_ip_group_id" = "direct"."id"
            LEFT OUTER JOIN "source_ips" "indirect" ON "indirect"."id" = "source_ip_memberships"."source_ip_net_id"
            WHERE (
             (bastions.active = true)
             AND
             (bastions.partition_id = #{partition_id})
             AND ((
             (direct.type = 'SourceIpNet')
            ) OR (
              (direct.type = 'SourceIpGroup')
              AND (source_ip_memberships.source_ip_net_id = indirect.id)
              AND (indirect.type = 'SourceIpNet')
            ))) GROUP BY bastions.id
SQL
    end

  end
end
