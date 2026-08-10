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

class SourceIpNet < SourceIp

  #-- Datatypes

  #-- Associations
  has_many :source_ip_memberships, dependent: :destroy
  has_many :source_ip_groups, -> { distinct }, through: :source_ip_memberships,
           after_add: :after_add_relation, after_remove: :after_remove_relation

  #-- Scopes

  scope :has_any_memberships, -> {
    joins("JOIN source_ip_memberships ON source_ips.id = source_ip_memberships.source_ip_net_id")
        .where("source_ip_memberships.source_ip_net_id IS NOT NULL").distinct
  }

  scope :has_not_any_memberships, -> {
    joins("LEFT JOIN source_ip_memberships ON source_ips.id = source_ip_memberships.source_ip_net_id")
        .where("source_ip_memberships.source_ip_net_id IS NULL").distinct
  }

  has_many :group_accesses, -> { distinct }, through: :source_ip_groups, source: :accesses
  has_many :group_bastions, -> { distinct }, through: :source_ip_groups, source: :bastions

  #-- Validations
  validate :validate_ip_address
  validates :ip_address, presence: true

  #-- Callbacks
  before_save :before_save_store_cidr_and_prefix

  #-- Class Methods

  class << self
    def skip_attributes_in_swift_log
      %w(ip4_first ip4_last ip6_first ip6_last prefix version)
    end

    def api_query_base
        self.includes([:source_ip_groups]).order('source_ips.name ASC')
    end
  end

  #-- Instance Methods

  def icon
    'fa-network-wired'
  end

  def title
    'Source Ip Network'
  end

  def identifier
    ip_address
  end

  def is_destroyable?
    return {false: 'Is provided by System'}  if system_int
    super
  end

  def IPAddress
    IPAddress.parse(self.ip_address)
  end

  #-- Methods used by config API
  def memberships
    self.source_ip_groups.pluck(:name)
  end

  def memberships=(values)
    self.source_ip_groups = SourceIpGroup.query_by_ids_or_names('memberships', self.partition_id, values)
  end

  def memberships_add(values)
    self.source_ip_groups << SourceIpGroup.query_by_ids_or_names('memberships', self.partition_id, values, self.source_ip_groups)
  end

  def memberships_remove(values)
    self.source_ip_groups.delete SourceIpGroup.query_by_ids_or_names('memberships', self.partition_id, values)
  end

  def version_label
    version == 4 ? 'IPv4' : 'IPv6'
  end

  private

  def before_save_store_cidr_and_prefix
    unless (ip = (IPAddress.parse(self.ip_address) rescue nil)).nil? then
      self.ip_address = ip.to_string
      self.version = ip.ipv6? ? 6 : 4
    end
    return true
  end

  def validate_ip_address
    unless self.ip_address.blank? then
      self.ip_address.strip!
      unless (IPAddress.parse(self.ip_address) rescue false) then
        errors.add(:ip_address, 'address is not a valid IPv4 or IPv6 network or host address')
      end
    end
  end

end