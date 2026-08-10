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

class TargetNetwork < Target

  include SwiftChangeTracker

  #-- Datatypes

  alias_attribute :network, :name

  #-- Associations

  has_many :target_memberships, dependent: :destroy, foreign_key: :target_id
  has_many :target_groups, -> { distinct }, through: :target_memberships,
           after_add: :after_add_relation, after_remove: :after_remove_relation

  has_many :group_accesses, -> { distinct }, through: :target_groups, source: :accesses

  #-- Scopes

  scope :has_any_memberships, -> {
    joins("JOIN target_memberships ON targets.id = target_memberships.target_id")
        .where("target_memberships.target_id IS NOT NULL").distinct
  }

  scope :has_not_any_memberships, -> {
    joins("LEFT JOIN target_memberships ON targets.id = target_memberships.target_id")
        .where("target_memberships.target_id IS NULL").distinct
  }

  #-- Callbacks

  before_validation :before_validation_normalize_network

  #-- Validations

  validates :network, :uniqueness => { case_sensitive: false, scope: [:partition_id, :proxy_id], message: 'network target with same name already exists within partition and proxy scope' }
  validate  :validate_network

  #-- Class Methods

  class << self

    def count_for_partition
      return 0 if User.current_user.partition.blank?
      TargetNetwork.where(partition: User.current_user.partition).count
    end

  end

  #-- Instance Methods

  def icon
    'fa-network-wired'
  end

  def display_name_a
    [self.name_with_proxy, "(Network)"]
  end

  def display_type
    'Network'
  end

  def target_user_host_keys
    TargetNetworkHost.where(proxy_id: self.proxy_id).where('name::inet << ?', self.network).map(&:target_user_host_keys).flatten
  end

  private

  def validate_network
    self.network.try(:strip!)
    unless self.network.blank? then
      ip = (IPAddress.parse(IPAddress.parse(self.network).network.to_string)) rescue nil
      self.network = ip.to_string if ip
      if ip.blank?
        errors.add(:network, 'address is not a valid IPv4 or IPv6 host address')
      else
        if (ip.ipv4? && ip.prefix == 32) || (ip.ipv6? && ip.prefix == 128)
          errors.add(:network, 'address is not a network but a single host. Please specify a network or use static target instead')
        end
      end
    else
      errors.add(:network, 'address is not a valid IPv4 or IPv6 host address or blank')
    end
  end

  def before_validation_normalize_network
    ip = (IPAddress.parse(IPAddress.parse(self.network).network.to_string)) rescue nil
    self.network = ip.try(:to_string)
  end

end