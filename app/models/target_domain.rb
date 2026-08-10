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

class TargetDomain < Target

  include SwiftChangeTracker

  #-- Datatypes

  alias_attribute :domainname, :name

  #-- Associations

  has_many :target_memberships, dependent: :destroy, foreign_key: :target_id
  has_many :target_groups, -> { distinct }, through: :target_memberships,
           after_add: :after_add_relation, after_remove: :after_remove_relation

  has_many :group_accesses, -> { distinct }, through: :target_groups, source: :accesses

  #-- Callbacks
  before_validation :before_validation_sanitize_domainname

  #-- Scopes

  scope :has_any_memberships, -> {
    joins("JOIN target_memberships ON targets.id = target_memberships.target_id")
        .where("target_memberships.target_id IS NOT NULL").distinct
  }

  scope :has_not_any_memberships, -> {
    joins("LEFT JOIN target_memberships ON targets.id = target_memberships.target_id")
        .where("target_memberships.target_id IS NULL").distinct
  }

  #-- Validations

  validates :domainname, presence: true
  validates :domainname, :uniqueness => { case_sensitive: false, scope: [:partition_id, :proxy_id], message: 'domain target with same name already exists within partition and proxy scope' }
  validates :domainname, format: { with: /\A[a-z0-9.\-]+\z/, message: 'contains invalid characters'  }
  validate  :validate_domainname

  #-- Class Methods

  class << self

    def count_for_partition
      return 0 if User.current_user.partition.blank?
      TargetDomain.where(partition: User.current_user.partition).count
    end

    def split_into_domains(fqdn)
      domains = []
      parts = fqdn.split('.')[1..-1]

      parts.size.times do |t|
        domains << ".#{parts[t..-1].join('.')}"
      end
      domains
    end

    def api_query_base
      self.includes([:target_groups, :proxy]).order('targets.name ASC')
    end
  end

  #-- Instance Methods

  def icon
    'fa-globe-africa'
  end

  def display_name_a
    ["*.#{self.name_with_proxy}", "(DNS Domain)"]
  end

  def display_type
    'DNS Domain'
  end

  def target_user_host_keys
    TargetDomainHost.where(proxy_id: self.proxy_id).where('name iLIKE ?', "%.#{self.name}").map(&:target_user_host_keys).flatten
  end

  private

  def validate_domainname
    errors.add('domainname', 'is not a fully qualified domainname') unless PublicSuffix.valid?(domainname, ignore_private: true)
  end

  def before_validation_sanitize_domainname
    (self.name = self.name.strip.gsub(/[.]+$/,'').downcase rescue nil)
  end

end