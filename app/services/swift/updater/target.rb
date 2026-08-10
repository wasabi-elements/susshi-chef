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

class Swift::Updater::Target
  class << self

    def swift_update(partition_id)
      targets = []

      SwiftTarget.transaction do

        @denied_addresses = PartitionSetting.find_by_partition_id(partition_id).DenyTargetAddresses

        # Delete old entries for this partition
        SwiftTarget.where(partition_id: partition_id).delete_all
        # Insert new entries for this partition
        TargetHost.includes(:proxy, :target_sockets, :target_host_keys, target_user_host_keys: [:susshi_user_login]).where(active: true, partition_id: partition_id).each do |target|
          host_keys  = target_host_keys(target)
          user_keys = target_user_host_keys(target)
          host_ids  = target.target_group_ids
          host_ids << target.id
          access_ids = AccessesTarget.where(target_id: host_ids).pluck(:access_id).uniq
          access_ids += target_fusion_access_ids(target.id)
          if access_ids.any?
            target.target_sockets.each do |socket|
              next if target.proxy.blank? and target_address_denied?(socket.host_ip_address)
              targets << SwiftTarget.new(kind:               'Static',
                                         target_id:          target.id,
                                         partition_id:       partition_id,
                                         target_ip:          socket.host_ip_address,
                                         access_ids:         access_ids,
                                         keys:               host_keys,
                                         user_keys:          user_keys,
                                         proxy_realm: target.proxy.try(:realm))
            end
          end
        end
        TargetDynamic.includes(:proxy, :target_host_keys, target_user_host_keys: [:susshi_user_login]).where(active: true, partition_id: partition_id).each do |target|
          host_keys  = target_host_keys(target)
          user_keys = target_user_host_keys(target)
          host_ids  = target.target_group_ids
          host_ids << target.id
          access_ids = AccessesTarget.where(target_id: host_ids).pluck(:access_id).uniq
          access_ids += target_fusion_access_ids(target.id)
          if access_ids.any?
            targets << SwiftTarget.new(kind:               'Dynamic',
                                       target_id:          target.id,
                                       partition_id:       partition_id,
                                       target_name:        target.name,
                                       access_ids:         access_ids,
                                       keys:               host_keys,
                                       user_keys:          user_keys,
                                       proxy_realm: target.proxy.try(:realm))
          end
        end
        TargetDomain.includes(:proxy).where(active: true, partition_id: partition_id).each do |target|
          host_ids  = target.target_group_ids
          host_ids << target.id
          access_ids = AccessesTarget.where(target_id: host_ids).pluck(:access_id).uniq
          access_ids += target_fusion_access_ids(target.id)
          if access_ids.any?
            targets << SwiftTarget.new(kind:               'Domain',
                                       target_id:          target.id,
                                       partition_id:       partition_id,
                                       target_name:        ".#{target.name}",
                                       access_ids:         access_ids,
                                       proxy_realm: target.proxy.try(:realm))
          end
        end
        TargetNetwork.includes(:proxy).where(active: true, partition_id: partition_id).each do |target|
          next if target.proxy.blank? and target_address_denied?(target.network)
          host_ids  = target.target_group_ids
          host_ids << target.id
          access_ids = AccessesTarget.where(target_id: host_ids).pluck(:access_id).uniq
          access_ids += target_fusion_access_ids(target.id)
          if access_ids.any?
            targets << SwiftTarget.new(kind:               'Network',
                                       target_id:          target.id,
                                       partition_id:       partition_id,
                                       target_ip:          target.network,
                                       access_ids:         access_ids,
                                       proxy_realm: target.proxy.try(:realm))
          end
        end
        SwiftTarget.import targets, :validate => false
      end
    end

    def target_host_keys(target)
      host_keys = {}
      target.target_host_keys.each do |key|
        host_keys[key.key_type] ||= []
        host_keys[key.key_type] << key.public_blob.split(/\s+/).last
      end
      return host_keys
    end

    def target_user_host_keys(target)
      user_keys = {}
      target.target_user_host_keys.each do |key|
        user_keys[key.susshi_user_login.name] ||= {}
        user_keys[key.susshi_user_login.name][key.key_type] ||= []
        user_keys[key.susshi_user_login.name][key.key_type] << key.public_blob.split(/\s+/).last
      end
      return user_keys
    end

    def target_fusion_access_ids(target_id)
      Swift::Updater::TargetFusion.target_fusions.select{|fusion| fusion.target_id == target_id}.map{|fusion| fusion.access_ids}.flatten
    end

    def target_address_denied?(address)
      @denied_addresses.select{|a| (IPAddress(a).include?(IPAddress(address)) rescue false)}.count > 0
    end

  end
end
