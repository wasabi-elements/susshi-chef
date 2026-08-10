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


require "test_helper"

CLIENT_IP_V4 = "10.200.1.15"
CLIENT_IP_V4_2 = "10.201.2.13"
CLIENT_IP_V6 = "2000::100:1"
CLIENT_IP_V4_WRONG = "1.1.1.1"
CLIENT_IP_V6_WRONG = "2000::101:2"

# CAS = SwiftClientAuthSet.where(partition_id: PART_ID).first
$partition = nil
$cas = nil
$susshi_user_ok = nil
$susshi_user_miss = nil

class SwiftIpCacheTestHelper
  class << self
    def lookup(source_ip:, swift_susshi_user: $susshi_user_ok, cache_idle_time: 3, max_cache_time: 10, create: false, refresh: false, whitelist: [])
      SwiftIpCaching.lookup(create:             create,
                            refresh:            refresh,
                            source_ip:          source_ip,
                            swift_susshi_user:  swift_susshi_user,
                            cache_idle_time:    cache_idle_time,
                            max_cache_time:     max_cache_time,
                            whitelist:          whitelist,
                            client_auth_set_id: $cas.id)
    end
  end
end


class SwiftIpCacheTest < ActiveSupport::TestCase

  def setup
    $partition = partitions(:the_partition)
    $cas = swift_client_auth_sets(:cas1)
    $susshi_user_ok = swift_susshi_users(:oliver)
    $susshi_user_miss = swift_susshi_users(:anonymous)
  end

  test "Entry for IP #{CLIENT_IP_V4}" do
    # Create cache entry
    cached = SwiftIpCacheTestHelper.lookup(create: true, refresh: true, source_ip: CLIENT_IP_V4)
    assert_not cached

    # Still valid
    cached = SwiftIpCacheTestHelper.lookup(create: true, refresh: true, source_ip: CLIENT_IP_V4)
    assert cached

    # Still valid after 2 seconds
    sleep 2
    cached = SwiftIpCacheTestHelper.lookup(create: true, refresh: true, source_ip: CLIENT_IP_V4)
    assert cached

    # Still valid after 4 seconds (2 seconds since last refresh)
    sleep 2
    cached = SwiftIpCacheTestHelper.lookup(create: true, refresh: true, source_ip: CLIENT_IP_V4)
    assert cached

    # Outdated after another 4 seconds, because not updated
    sleep 4
    cached = SwiftIpCacheTestHelper.lookup(source_ip: CLIENT_IP_V4)
    assert_not cached
  end

  test "Entry for IP #{CLIENT_IP_V6}" do
    SwiftIpCaching.all.destroy_all

    # Create cache entry
    cached = SwiftIpCacheTestHelper.lookup(create: true, refresh: true, source_ip: CLIENT_IP_V6)
    assert_not cached

    # Still valid
    cached = SwiftIpCacheTestHelper.lookup(create: true, refresh: true, source_ip: CLIENT_IP_V6)
    assert cached

    # Still valid after 2 seconds
    sleep 2
    cached = SwiftIpCacheTestHelper.lookup(create: true, refresh: true, source_ip: CLIENT_IP_V6)
    assert cached

    # Still valid after 4 seconds (2 seconds since last refresh)
    sleep 2
    cached = SwiftIpCacheTestHelper.lookup(create: true, refresh: true, source_ip: CLIENT_IP_V6)
    assert cached

    # Outdated after another 4 seconds, because not updated
    sleep 4
    cached = SwiftIpCacheTestHelper.lookup(source_ip: CLIENT_IP_V6)
    assert_not cached
  end

  test "Entry for IP #{CLIENT_IP_V4} and do not refresh" do
    SwiftIpCaching.all.destroy_all

    # Create cache entry
    cached = SwiftIpCacheTestHelper.lookup(create: true, source_ip: CLIENT_IP_V4)
    assert_not cached

    # Test if valid
    cached = SwiftIpCacheTestHelper.lookup(source_ip: CLIENT_IP_V4)
    assert cached

    # Sleep a bit
    sleep 3.5
    cached = SwiftIpCacheTestHelper.lookup(source_ip: CLIENT_IP_V4)
    assert_not cached
  end

  test "Entry for IP #{CLIENT_IP_V4} and check for max time expiry" do
    SwiftIpCaching.all.destroy_all

    # Create cache entry
    cached = SwiftIpCacheTestHelper.lookup(create: true, refresh: true, source_ip: CLIENT_IP_V4)
    assert_not cached

    # Test if valid
    [1..3].each do
      sleep 2
      cached = SwiftIpCacheTestHelper.lookup(refresh: true, source_ip: CLIENT_IP_V4)
      assert cached
    end

    # Sleep a bit
    sleep 3.5
    cached = SwiftIpCacheTestHelper.lookup(refresh: true, source_ip: CLIENT_IP_V4)
    assert_not cached
  end

  test "Entry for IP #{CLIENT_IP_V4_2} and test against wrong IP #{CLIENT_IP_V4}" do
    SwiftIpCaching.all.destroy_all

    # Create cache entry
    cached = SwiftIpCacheTestHelper.lookup(create: true, refresh: true, source_ip: CLIENT_IP_V4_2)
    assert_not cached

    # Test another IP
    cached = SwiftIpCacheTestHelper.lookup(source_ip: CLIENT_IP_V4)
    assert_not cached

    # Test another IP (with creation)
    cached = SwiftIpCacheTestHelper.lookup(create: true, source_ip: CLIENT_IP_V4)
    assert_not cached

    # Test original IP
    cached = SwiftIpCacheTestHelper.lookup(source_ip: CLIENT_IP_V4)
    assert cached
  end

end
