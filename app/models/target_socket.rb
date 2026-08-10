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

class TargetSocket < ApplicationRecord

  include SwiftChangeTracker

  #-- Datatypes

  #-- Associations
  belongs_to :target_host

  # Delegations used for SwiftChangeTracker
  delegate :partition, to: :target_host
  delegate :name, to: :target_host

  #-- Scopes

  #-- Validations
  validates :ip_address, uniqueness: { case_sensitive: false, scope: :target_host, message: 'same IP address already exists for this target' }
  validate :validate_ip_address
  validate :validate_port_range

  #-- Callbacks
  before_validation :before_validation_store_cidr_and_prefix
  before_validation :before_validation_store_ports

  #-- Class Methods

  class << self
    def skip_attributes_in_swift_log
      %w(port_min port_max)
    end
  end

  #-- Instance Methods

  def is_host_address?
    self.version == 4 ? (self.IPAddress.prefix == 32) : (self.IPAddress.prefix == 128)
  end

  def host_ip_address
    return nil unless is_host_address?
    ip_address.gsub(/\/(32|128)/, '')
  end

  def IPAddress
    IPAddress.parse(self.ip_address)
  end

  private

  def before_validation_store_cidr_and_prefix
    if (ip = (IPAddress.parse(self.ip_address) rescue nil)).nil?
      errors.add(:ip_address, "invalid IP address '#{self.ip_address}'")
      false
    else
      self.ip_address = ip.to_string
      self.version = ip.ipv6? ? 6 : 4
      true
    end
  end

  def before_validation_store_ports
    if self.port_range.blank?
      self.port_min = 22
    else
      self.port_min,self.port_max = self.port_range.gsub(' ','').split('-').collect{|x|x.to_i}
    end
    self.port_max ||= self.port_min
    self.port_range = self.port_min != self.port_max ? "#{self.port_min} - #{self.port_max}" : "#{self.port_min}"
  end

  def validate_ip_address
    unless self.ip_address.blank? then
      if (ip = IPAddress.parse(self.ip_address) rescue nil).nil? then
        errors.add(:ip_address, 'address is not a valid IPv4 or IPv6 host address')
      else
        if (ip.ipv4? && ip.prefix != 32) || (ip.ipv6? && ip.prefix != 128)
          errors.add(:ip_address, 'address is not of valid length. Use /32 for IPv4 or /128 for IPv6')
        end
      end
    end
  end

  def validate_port_range
    if self.port_range.blank?
      min = max = 22
    else
      min,max = self.port_range.gsub(' ','').split('-').collect{|x|x.to_i}
      max ||= min
    end
    return if min >= 22 && min <= max && max < 65535
    errors.add(:port_range, 'invalid range. Valid range is 22 - 65534')
  end

end
