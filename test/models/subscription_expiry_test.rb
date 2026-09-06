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

# Nothing renews a mounted token file, so thirty days is the right lead time and
# the sentence says what an administrator has to do something about. The
# Enterprise Edition replaces this where the subscription is fetched online.
class SubscriptionExpiryTest < ActiveSupport::TestCase

  test "a month before the end there is nothing to say" do
    assert_nil warning_for(31)
  end

  test "inside thirty days it says how long is left" do
    assert_equal "Your subscription will expire in 20 days.", warning_for(20)
  end

  test "one day is singular" do
    assert_equal "Your subscription will expire in 1 day.", warning_for(1)
  end

  test "the last day says today" do
    assert_equal "Your subscription expires today.", warning_for(0)
  end

  # Past the end the dashboard shows the expired state instead, but the API asks
  # without that guard.
  test "past the end it still answers" do
    assert_equal "Your subscription expires today.", warning_for(-3)
  end

  private

  # No subscription key, so this is the core behaviour even with the Enterprise
  # Edition loaded.
  def warning_for(days)
    subscription = Subscription.new
    subscription.define_singleton_method(:expires_in_days) { days }
    subscription.expiry_warning
  end

end
