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

PARTITION_ID = 1
SUSSHI_USER = "oliver"
TARGET_USER = "admin"
TARGET_IP_V4 = "10.200.1.15"
TARGET_IP_V4_2 = "10.201.2.13"
TARGET_IP_V6 = "2000::100:1"
TARGET_IP_V4_WRONG = "1.1.1.1"
TARGET_IP_V6_WRONG = "2000::101:2"
SUSSHI_UNIQ_ID = "1234-1234-1234-1234-1234"

PASSWORD_LEN = 20

class SwiftDotpTicketTestHelper
  class << self
    def create_ticket(valid_time, identity: nil, susshi_uniqid: SUSSHI_UNIQ_ID)
      SwiftDotpTicket.create_ticket(
        partition_id: PARTITION_ID,
        target_user: TARGET_USER,
        target_identity: identity,
        password_length: PASSWORD_LEN,
        susshi_uniqid: susshi_uniqid,
        valid_time: valid_time
      )
    end
  end
end

class SwiftDotpTicketTest < ActiveSupport::TestCase

  test "Create ticket" do
    ticket_pw = SwiftDotpTicketTestHelper.create_ticket(5)
    assert_not ticket_pw.blank?
    assert ticket_pw.length == PASSWORD_LEN
  end


  test "Create and lookup ticket" do
    ticket_pw = SwiftDotpTicketTestHelper.create_ticket(5)

    assert SwiftDotpTicket.lookup_ticket(
      partition_id: PARTITION_ID,
      target_user: TARGET_USER,
      target_password: ticket_pw
    )
  end

  test "Create and lookup ticket after expiration" do
    ticket_pw = SwiftDotpTicketTestHelper.create_ticket(2)

    sleep 2.3

    assert_not SwiftDotpTicket.lookup_ticket(
      partition_id: PARTITION_ID,
      target_user: TARGET_USER,
      target_password: ticket_pw
    )
  end

  test "Create and lookup ticket twice" do
    ticket_pw = SwiftDotpTicketTestHelper.create_ticket(5)

    assert SwiftDotpTicket.lookup_ticket(
      partition_id: PARTITION_ID,
      target_user: TARGET_USER,
      target_password: ticket_pw
    )

    assert_not SwiftDotpTicket.lookup_ticket(
      partition_id: PARTITION_ID,
      target_user: TARGET_USER,
      target_password: ticket_pw
    )
  end

  test "Create and lookup ticket with wrong PW" do
    ticket_pw = SwiftDotpTicketTestHelper.create_ticket(5)

    assert_not SwiftDotpTicket.lookup_ticket(
      partition_id: PARTITION_ID,
      target_user: TARGET_USER,
      target_password: ticket_pw.reverse
    )
  end

  test "Create and lookup ticket with matching IP" do
    ticket_pw = SwiftDotpTicketTestHelper.create_ticket(5, identity: TARGET_IP_V4)

    assert SwiftDotpTicket.lookup_ticket(
      partition_id: PARTITION_ID,
      target_user: TARGET_USER,
      target_identity: TARGET_IP_V4,
      target_password: ticket_pw
    )
  end

  test "Create and lookup ticket with matching IPv6" do
    ticket_pw = SwiftDotpTicketTestHelper.create_ticket(5, identity: TARGET_IP_V6)

    assert SwiftDotpTicket.lookup_ticket(
      partition_id: PARTITION_ID,
      target_user: TARGET_USER,
      target_identity: TARGET_IP_V6,
      target_password: ticket_pw
    )
  end

  test "Create and lookup ticket with not matching IP" do
    ticket_pw = SwiftDotpTicketTestHelper.create_ticket(5, identity: TARGET_IP_V4)

    assert_not SwiftDotpTicket.lookup_ticket(
      partition_id: PARTITION_ID,
      target_user: TARGET_USER,
      target_identity: TARGET_IP_V4_WRONG,
      target_password: ticket_pw
    )

    ticket_pw = SwiftDotpTicketTestHelper.create_ticket(5, identity: TARGET_IP_V6)

    assert_not SwiftDotpTicket.lookup_ticket(
      partition_id:    PARTITION_ID,
      target_user:     TARGET_USER,
      target_identity: TARGET_IP_V6_WRONG,
      target_password: ticket_pw
    )
  end

  test "Create and lookup multiple tickets for same susshi_user / target_user but different sessions" do
    ticket_pw1 = SwiftDotpTicketTestHelper.create_ticket(5, susshi_uniqid: '12340')
    ticket_pw2 = SwiftDotpTicketTestHelper.create_ticket(5, susshi_uniqid: '12341')
    ticket_pw3 = SwiftDotpTicketTestHelper.create_ticket(5, susshi_uniqid: '12342')
    ticket_pw4 = SwiftDotpTicketTestHelper.create_ticket(5, susshi_uniqid: '12343')

    assert SwiftDotpTicket.lookup_ticket(
      partition_id: PARTITION_ID,
      target_user: TARGET_USER,
      target_password: ticket_pw4
    )

    assert SwiftDotpTicket.lookup_ticket(
      partition_id: PARTITION_ID,
      target_user: TARGET_USER,
      target_password: ticket_pw1
    )

    assert SwiftDotpTicket.lookup_ticket(
      partition_id: PARTITION_ID,
      target_user: TARGET_USER,
      target_password: ticket_pw3
    )

    assert SwiftDotpTicket.lookup_ticket(
      partition_id: PARTITION_ID,
      target_user: TARGET_USER,
      target_password: ticket_pw2
    )

    assert_not SwiftDotpTicket.lookup_ticket(
      partition_id: PARTITION_ID,
      target_user: TARGET_USER,
      target_password: ticket_pw2
    )
  end

  test "Create and lookup multiple tickets for same susshi_user / target_user on different IPs but same session" do
    ticket_pw1 = SwiftDotpTicketTestHelper.create_ticket(5, identity: id1 = '1.1.1.1')
    ticket_pw2 = SwiftDotpTicketTestHelper.create_ticket(5, identity: id2 = 'test-server-1')
    ticket_pw3 = SwiftDotpTicketTestHelper.create_ticket(5, identity: id3 = '2.2.2.2')
    ticket_pw4 = SwiftDotpTicketTestHelper.create_ticket(5, identity: id4 = '3.3.3.3')

    assert SwiftDotpTicket.lookup_ticket(
      partition_id: PARTITION_ID,
      target_user: TARGET_USER,
      target_identity: id4,
      target_password: ticket_pw4
    )

    # Lookup of first Ticket should already have deleted all tickets for this session

    assert_not SwiftDotpTicket.lookup_ticket(
      partition_id: PARTITION_ID,
      target_user: TARGET_USER,
      target_identity: id1,
      target_password: ticket_pw1
    )

    assert_not SwiftDotpTicket.lookup_ticket(
      partition_id: PARTITION_ID,
      target_user: TARGET_USER,
      target_identity: id3,
      target_password: ticket_pw3
    )

    assert_not SwiftDotpTicket.lookup_ticket(
      partition_id: PARTITION_ID,
      target_user: TARGET_USER,
      target_identity: id2,
      target_password: ticket_pw2
    )

    assert_not SwiftDotpTicket.lookup_ticket(
      partition_id: PARTITION_ID,
      target_user: TARGET_USER,
      target_password: ticket_pw2
    )
  end

end
