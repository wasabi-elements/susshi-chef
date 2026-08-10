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
require "jwt"

PARTITION_ID  = 1
USERINFO      = { username: "oliver", name: "Oliver Rauscher" }
SUSSHI_UNIQID = "20251015-044155-0001-26461"
SECRET_LENGTH = 32

JWT = { "aud" => "AUD", "iss" => "https://issuer/application/o/susshi/", "sid" => "SID", "sub" => "oliver" }

class SwiftAuthTicketTestHelper
  class << self
    def create_ticket(max_issue_time: 1.minute, max_store_time: 10.minutes, susshi_user: $susshi_user_ok, susshi_uniqid: SUSSHI_UNIQID, secret_length: SECRET_LENGTH, state: :created)
      SwiftAuthTicket.create_ticket(
        partition_id:   PARTITION_ID,
        susshi_user_id: susshi_user.id,
        susshi_uniqid:,
        max_issue_time:,
        max_store_time:,
        secret_length:,
        state:
      )
    end
  end
end

class SwiftAuthTicketTest < ActiveSupport::TestCase

  def setup
    $partition        = partitions(:the_partition)
    $susshi_user_ok   = swift_susshi_users(:oliver)
    $susshi_user_miss = swift_susshi_users(:anonymous)
  end

  test "Create ticket" do
    ticket = SwiftAuthTicketTestHelper.create_ticket(max_issue_time: 5)
    assert_not ticket.secret.blank?
    assert ticket.secret.length == SECRET_LENGTH
  end

  test "Create and lookup ticket" do
    ticket = SwiftAuthTicketTestHelper.create_ticket(max_issue_time: 5, state: :issued)

    assert SwiftAuthTicket.validate_ticket(
      secret: ticket.secret,
      jwt:    JWT
    )
  end

  test "Create and lookup ticket after expiration" do
    ticket = SwiftAuthTicketTestHelper.create_ticket(max_issue_time: 2, state: :issued)

    sleep 2.3

    assert_not SwiftAuthTicket.validate_ticket(
      secret: ticket.secret,
      jwt:    JWT
    )
  end

  test "Create and lookup ticket twice" do
    ticket = SwiftAuthTicketTestHelper.create_ticket(state: :issued)
    secret = ticket.secret

    assert SwiftAuthTicket.validate_ticket(
      secret: secret,
      jwt:    JWT
    )

    assert_not SwiftAuthTicket.validate_ticket(
      secret: secret,
      jwt:    JWT
    )
  end

  test "Create and lookup ticket twice but with different states" do
    ticket = SwiftAuthTicketTestHelper.create_ticket(state: :issued)
    secret = ticket.secret

    assert SwiftAuthTicket.validate_ticket(
      secret: secret,
      jwt:    JWT
    )

    assert SwiftAuthTicket.validate_ticket(
      secret: secret,
      jwt:    JWT,
      state:  :validated
    )
  end

  test "Create and lookup ticket with wrong secret" do
    SwiftAuthTicketTestHelper.create_ticket(max_issue_time: 5, state: :issued)

    assert_not SwiftAuthTicket.validate_ticket(
      secret: "wrong_secret"
    )
  end

end
