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

class SwiftIpCaching < ApplicationRecord

  belongs_to :swift_susshi_user

  class << self

    #
    # Lookup IP Caching
    # -----------------
    # source_ip:            Source IP address as string
    # swift_susshi_user:    Reference to Swift Susshi User (Option 1)
    # swift_susshi_user_id: Swift Susshi User ID (overwrites swift_susshi_user) (Option 2)
    # cache_idle_time:      Time, this entry should be valid between sessions
    # max_cache_time:       Time, this entry should be valid in total
    # refresh:              If true, object is created on lookup (default is false)
    # ipv4_prefix:          source_ip is stored with given IPv4 network prefix (defaults to 32)
    # ipv6_prefix:          source_ip is stored with given IPv6 network prefix (defaults to 128)
    # whitelist:            Array of networks (strings), that are whitelisted
    #
    def lookup(source_ip:, swift_susshi_user: nil, swift_susshi_user_id: nil, cache_idle_time: 3600, max_cache_time: 28800, refresh: false, create: false,
               ipv4_prefix: 32, ipv6_prefix: 128, whitelist: [], client_auth_set_id: 0)

      create = ActiveModel::Type::Boolean.new.cast(create)
      refresh = ActiveModel::Type::Boolean.new.cast(refresh)
      rc = false

      if whitelisted?(whitelist, source_ip)
        rc = true
      else
        user_id = swift_susshi_user_id ? swift_susshi_user_id : (swift_susshi_user.id rescue nil)
        return false if user_id.blank?
        cache = SwiftIpCaching.where('source_ip >>= ?', source_ip).where(swift_susshi_user_id: user_id, client_auth_set_id: client_auth_set_id).first

        # Determine if cached entry is valid?
        if cache
          if (cache.created_at + max_cache_time) > Time.now
            rc = if refresh
                   (cache.updated_at + cache_idle_time) > Time.now ? true : false
                 else
                   true
                 end
          end
          if rc
            if refresh
              #- Touch existing and still valid entry if refresh
              cache.touch
            end
            return rc
          else
            if create
              #- Reuse existing, but outdated entry
              cache.update_columns(created_at: Time.now, updated_at: Time.now)
            else
              cache.destroy
            end
            return rc
          end
        else
          if create
            #- Create new entry
            # Mask IP address
            sip = IPAddress(source_ip)
            sip.prefix = sip.ipv4? ? ipv4_prefix : ipv6_prefix
            SwiftIpCaching.create(source_ip: sip.network.to_string, swift_susshi_user_id: user_id, client_auth_set_id: client_auth_set_id) if create
          end
        end
      end
      rc
    end

    #
    # Create IP Caching Entry
    # -----------------------
    # source_ip:            Source IP address as string
    # swift_susshi_user:    Reference to Swift Susshi User (Option 1)
    # swift_susshi_user_id: Swift Susshi User ID (overwrites swift_susshi_user) (Option 2)
    # cache_idle_time:      Time, this entry should be valid
    # max_cache_time:       Time, this entry should be valid in total
    # refresh:              If true, object is created on lookup (default is false)
    # ipv4_prefix:          source_ip is stored with given IPv4 network prefix (defaults to 32)
    # ipv6_prefix:          source_ip is stored with given IPv6 network prefix (defaults to 128)
    # whitelist:            Array of networks (strings), that are whitelisted
    #
    def create_entry(source_ip:, swift_susshi_user: nil, swift_susshi_user_id: nil, cache_idle_time: 3600, max_cache_time: 28800,
                     ipv4_prefix: 32, ipv6_prefix: 128, whitelist: [], client_auth_set_id: 0)

      lookup(create: true, source_ip: source_ip, swift_susshi_user: swift_susshi_user, swift_susshi_user_id: swift_susshi_user_id,
             cache_idle_time: cache_idle_time, max_cache_time: max_cache_time,
             ipv4_prefix: ipv4_prefix, ipv6_prefix: ipv6_prefix, whitelist: whitelist,
             client_auth_set_id: client_auth_set_id)
    end

    def whitelisted?(whitelist, ip)
      return false if whitelist.blank?
      whitelist.select{|net| IPAddress(net).include?(IPAddress(ip))}.size > 0
    end

    def garbage_collect(cache_max_time)
      cache_max_time ||= 86400
      SwiftIpCaching.where('created_at < ?', Time.now - cache_max_time.to_i).delete_all
    end

  end

end
