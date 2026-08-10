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

class SwiftDotpTicket < ApplicationRecord

  encrypts :target_password, :target_identity

  @@garbage_time = Time.now - 86400

  #-- Datatypes

  #-- Associations

  #-- Scopes

  #-- Validations
  validates :partition_id, presence: true
  validates :target_user, presence: true
  validates :target_password, presence: true
  validates :valid_until, presence: true

  #-- Callbacks
  before_save :before_save_hash_password

  #-- Class Methods

  class << self

    #
    # Create Target Auth DotpTicket
    # -----------------------------
    # partition_id:      Partition ID
    # target_user:       Target User (string)
    # target_identity:   Target Identity (string)
    # valid_time:        Time in seconds, entry is valid
    # password_length:   Length of generated password
    # susshi_uniqid:     Session ID
    #
    # return:
    #
    # One-Time-Password:
    #   n<dynamic>  -> Don't match Identities
    #   i<dynamic>  -> Match on Identity
    #
    def create_ticket(partition_id:, target_user:, target_identity: nil, valid_time:, password_length:, susshi_uniqid:)
      garbage_collect # TODO --> Move to cronjob
      target_password = (target_identity.blank? ? 'n' : 'i') + SecureRandom.alphanumeric(password_length - 1)
      SwiftDotpTicket.create(
        partition_id:    partition_id,
        target_user:     target_user,
        target_identity: target_identity,
        target_password: target_password,
        susshi_uniqid:   susshi_uniqid,
        valid_until:     Time.now + valid_time
      )
      return target_password
    end

    #
    # Lookup Target Auth DotpTicket
    # -----------------------------
    #
    # target_user:       Target User (string)
    # target_password:   Target Password (string)
    # target_identity:   TargetIdentity (string)
    #
    def lookup_ticket(partition_id:, target_user:, target_password:, target_identity: nil)
      garbage_collect # TODO --> Move to cronjob

      tickets = SwiftDotpTicket.where(
        partition_id: partition_id,
        target_user:  target_user
      ).where('valid_until > ?', Time.now)

      unless target_identity.blank? or target_password[0] != 'i'
        tickets = tickets.where(target_identity: target_identity)
      else
        tickets = tickets.where('target_identity IS NULL')
      end

      tickets.each do |ticket|
        if compare_password(ticket.target_password, target_password)
          SwiftDotpTicket.where(susshi_uniqid: ticket.susshi_uniqid).delete_all
          return true
        end
      end
      return false
    end

    #
    # Garbage collect every 5 minutes
    #
    def garbage_collect
      if (Time.now - @@garbage_time) > 300
        SwiftDotpTicket.where('valid_until < ?', Time.now).delete_all
        @@garbage_time = Time.now
      end
    end

    private

    def compare_password(hashed_password, password)
      if (terms = hashed_password.split('$') rescue []).size == 4
        hashed_password == "$6$#{terms[2]}$#{Digest::SHA512.hexdigest("#{terms[2]}#{password}")}"
      else
        false
      end
    end

  end

  #-- Instance Methods

  private

  def before_save_hash_password
    return if self.target_password.blank?
    salt = SecureRandom.hex(4)
    self.target_password = "$6$#{salt}$#{Digest::SHA512.hexdigest("#{salt}#{self.target_password}")}"
  end

end
