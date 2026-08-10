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

class SwiftAuthTicket < ApplicationRecord

  MAX_ISSUE_TIME = 2.minutes
  MAX_STORE_TIME = 7.days

  @@garbage_time = Time.now - MAX_ISSUE_TIME * 2

  #-- Datatypes

  typed_store :jwt, prefix: :jwt, coder: Chef::JsonbCoder do |t|
    t.string :aud
    t.string :iss
    t.string :sid
    t.string :sub
  end

  enum :state, { created: 0, issued: 1, validated: 2}, default: :created

  #-- Validations
  validates :state, presence: true
  validates :secret, presence: true
  validates :stored_until, presence: true

  #-- Queries
  scope :where_jwt_aud, ->(value) {
    where("jwt ->> 'aud' = ?", value)
  }

  scope :where_jwt_iss, ->(value) {
    where("jwt ->> 'iss' = ?", value)
  }

  scope :where_jwt_sid, ->(value) {
    where("jwt ->> 'sid' = ?", value)
  }

  scope :where_jwt_sub, ->(value) {
    where("jwt ->> 'sub' = ?", value)
  }

  scope :with_susshi_uniqid, ->(value) {
    where("? = ANY(susshi_uniqids)", value)
  }

  #-- Class methods
  class << self

    #
    # Create Client Auth Ticket
    # -------------------------
    # partition_id:      (Swift) Partition ID
    # susshi_user_id:    (Swift) Susshi User ID
    # max_issue_time:    Time in seconds or timeperiod, issue is valid
    # max_store_time:    Time in seconds, the ticket is stored max. and not deleted by garbage collection
    # susshi_uniqid:     Session ID
    # secret_length:     Length of secret (default 32)
    # state:             see enum state
    # session_end_on_logout: boolean wether to end the session on OIDC backchannel-logout or not
    #
    # return:
    #
    # ticket:           SwiftAuthTicket
    #
    def create_ticket(partition_id:, susshi_user_id: nil, susshi_uniqid:, secret_length: 32, state: :created, max_issue_time: MAX_ISSUE_TIME, max_store_time: MAX_STORE_TIME, session_end_on_logout: false, source_ip: nil)
      garbage_collect

      issued_until = if state == :issued
        Time.now + max_issue_time
      end

      max_store_time = MAX_STORE_TIME if (max_store_time || MAX_STORE_TIME) >= MAX_STORE_TIME

      # The 'ticket_match' attribute has a database index with guaranteed uniqueness
      ticket_match = "#{susshi_user_id}:#{source_ip}:#{state}"

      SwiftAuthTicket.transaction do
        begin
          # Find a ticket or create a new one
          ticket = SwiftAuthTicket.where('issued_until > ?', Time.now).lock.find_or_create_by(partition_id:, ticket_match:) do |t|
            t.source_ip = source_ip
            t.susshi_user_id = susshi_user_id
            t.secret = SecureRandom.alphanumeric(secret_length)
            t.state = state
            t.session_end_on_logout = session_end_on_logout
            t.issued_until = issued_until
            t.stored_until = Time.now + max_store_time
          end
        rescue
          # Ticket must already be created by another process and thus be blocked by the database due to index non-uniqueness constrain on 'ticket_match'

          # Let's see if it is still fresh and can be used
          ticket = SwiftAuthTicket.where('issued_until > ?', Time.now).lock.find_by(partition_id:, ticket_match:)

          if ticket.nil?
            # No fresh ticket found, so something locked up in a bad state with ticket_match, this could happen from user canceling / exceeding time during OIDC authentication

            # -> start over and get a new ticket
            SwiftAuthTicket.where(ticket_match:).destroy_all

            ticket = SwiftAuthTicket.create(
              partition_id:,
              source_ip:,
              secret: SecureRandom.alphanumeric(secret_length),
              state:,
              susshi_user_id:,
              session_end_on_logout:,
              ticket_match:,
              issued_until: state == :issued ? Time.now + max_issue_time : nil,
              stored_until: Time.now + max_store_time
            )
          end
        end

        if ticket
          ticket.susshi_uniqids << susshi_uniqid
          if ticket.save
            ticket
          else
            nil
          end
        else
          nil
        end
      end
    end

    #
    # Validate Client Auth AuthTicket
    # -------------------------------
    #
    # secret:           Presented secret
    # jwt:              Information from Access Token from Webrequest (JWT)
    # state:            must match on enum state
    # success_state:    set to this enum state after successful read
    #
    # return:
    #
    # ticket:           SwiftAuthTicket
    #
    def validate_ticket(secret:, jwt: nil, state: :issued, success_state: :validated)

      while true # Just to break out in case of @auth_hook.error

        break unless jwt.present?

        uid = jwt["uid"]
        break unless uid.present?

        susshi_user = SwiftSusshiUser.find_by(name: uid)
        break unless susshi_user

        ticket = SwiftAuthTicket.order(issued_until: :desc).where(secret:, susshi_user_id: susshi_user.id, state:).where('stored_until > ?', Time.now)
        ticket = ticket.where('issued_until > ?', Time.now) if state == :issued
        ticket = ticket.first
        break unless ticket

        # Update token with JWT values
        ticket.safely_store_jwt_attributes(jwt)

        # Update state
        if success_state
          ticket.state = success_state
          ticket.ticket_match = nil  # NULL is not unique in index uniqueness
        end

        # Save back ticket
        ticket.save

        return ticket
      end
    end

    #
    # Logout with given Logout Token
    # ------------------------------
    #
    # jwt:            Information from Access Token from Webrequest (JWT)
    #
    # return:
    #
    # true:           Successful signed out
    # false:          Failure on sign out
    #
    def logout(jwt:)
      return false unless jwt.present?

      # sub or sid must be present in logout token
      if jwt["sub"].blank? && jwt["sid"].blank?
        return false
      end

      # Find all tickets
      tickets = SwiftAuthTicket.where_jwt_iss(jwt["iss"]).where_jwt_aud(jwt["aud"])
      tickets = tickets.where_jwt_sub(jwt["sub"]) if jwt["sub"]
      tickets = tickets.where_jwt_sid(jwt["sid"]) if jwt["sid"]

      if tickets.any?
        # Get SusshiUser from Tokens
        susshi_user_id = tickets.first.susshi_user_id

        # Destroy all SwiftIpCachings for the user
        cachings = SwiftIpCaching.where(swift_susshi_user_id: susshi_user_id)
        cachings.destroy_all

        # TODO: (Optional) Logout User sessions if any in background
        logout_uniq_ids = tickets.select do |ticket|
          ticket.session_end_on_logout == true
        end.map do |ticket|
          ticket.susshi_uniqids
        end.flatten

        if logout_uniq_ids.any?
          logout_uniqids_in_background(logout_uniq_ids)
        end

        # Destroy all tickets
        tickets.destroy_all

        return true
      end
    end

    #
    # Logout sessions with given susshi_uniqids
    # ------------------------------
    # TODO: Operate in background
    #
    def logout_uniqids_in_background(uniqids)
      SessionReport.where(session_state: %w[new active])
                   .where(susshi_uniqid: uniqids)
                   .each do |session_report|
        Susshid::RemoteControl.terminate(session_report)
      end
    end

    #
    # Find ticket with susshi_uniqid and delete the uniqid from the list. If it is the last session of an ticket, also the ticket gets removed
    # ------------------------------
    #
    def remove_susshi_uniqid(uniqid)
      if (ticket = SwiftAuthTicket.with_susshi_uniqid(uniqid).first)
        ticket.susshi_uniqids.delete(uniqid)
        ticket.save
      end
    end

    #
    # Garbage collect every 5 minutes
    # ------------------------------
    #
    def garbage_collect
      if (Time.now - @@garbage_time) > 300
        SwiftAuthTicket.where(state: :validated).where('stored_until < ?', Time.now).delete_all
        SwiftAuthTicket.where(state: [:created, :issued]).where('issued_until < ?', Time.now).delete_all
        @@garbage_time = Time.now
      end
    end

  end

  #-- Instance methods

  #
  # Add a susshi_uniqid to a ticket
  #
  def add_susshi_uniqid(susshi_uniqid)
    self.susshi_uniqids << susshi_uniqid
    self.save
  end

  #
  # Store JWT values from hash to attributes
  #
  def safely_store_jwt_attributes(payload)
    %w[aud iss sid sub].each do |key|
      self.assign_attributes("jwt_#{key}".to_sym => payload.dig(key))
    end
  end


end
