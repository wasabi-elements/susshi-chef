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

# Initialize Preference before starting
require Rails.root.join("app/models/preference").to_s
require Rails.root.join("app/lib/errors/totp").to_s

$partition = nil
class SusshiUserLoginTest < ActiveSupport::TestCase

  def setup
    $partition = partitions(:the_partition)
  end

  test "Create login user" do
    user = SusshiUserLogin.create(partition: $partition, fullname: "Joe Test", name: "joe_test")
    assert user
  end

  test "Generate TOTP token for login user" do
    user = SusshiUserLogin.create(partition: $partition, fullname: "Joe Test", name: "joe_test")
    assert user
    user.generate_totp_secret!
    assert user.totp_secret
  end

  test "Test TOTP token can be used only once" do
    user = SusshiUserLogin.create(partition: $partition, fullname: "Joe Test", name: "joe_test")
    user.generate_totp_secret!
    totp = ROTP::TOTP.new(user.totp_secret).at(Time.now)
    assert user.verify_totp!(totp)
    assert_raises Errors::Totp::Verification do
      user.verify_totp!(totp)
    end
  end

  test "Test TOTP token can be used only once even in parallel threads" do
    user = SusshiUserLogin.create(partition: $partition, fullname: "Joe Test", name: "joe_test")
    user.generate_totp_secret!
    totp = ROTP::TOTP.new(user.totp_secret).at(Time.now)

    threads = []
    exceptions = 0
    200.times do
      threads << Thread.new do
        begin
          user.verify_totp!(totp)
        rescue Errors::Totp::Verification
          exceptions += 1
        end
      end
    end
    threads.map(&:join)

    assert_equal 199, exceptions
  end

end
