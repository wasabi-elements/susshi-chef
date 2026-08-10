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

class TargetDynamic < Target

  include SwiftChangeTracker

  #-- Datatypes

  alias_attribute :hostname, :name

  #-- Associations

  has_many :target_memberships, dependent: :destroy, foreign_key: :target_id
  has_many :target_groups, -> { distinct }, through: :target_memberships,
           after_add: :after_add_relation, after_remove: :after_remove_relation

  has_many :target_host_keys, -> { where(susshi_user_login_id: nil) },
           foreign_key: 'target_id', dependent: :destroy,
           after_add: :after_add_relation, after_remove: :after_remove_relation

  has_many :target_user_host_keys, -> { where.not(susshi_user_login_id: nil) },
           class_name: 'TargetHostKey',
           foreign_key: 'target_id', dependent: :destroy,
           after_add: :after_add_relation, after_remove: :after_remove_relation

  has_many :group_accesses, -> { distinct }, through: :target_groups, source: :accesses

  accepts_nested_attributes_for :target_host_keys, :allow_destroy => true

  #-- Callbacks
  before_validation :before_validation_sanitize_hostname
  after_commit :favor_system_wide_host_keys

  #-- Scopes

  scope :has_any_memberships, -> {
    joins("JOIN target_memberships ON targets.id = target_memberships.target_id")
        .where("target_memberships.target_id IS NOT NULL").distinct
  }

  scope :has_not_any_memberships, -> {
    joins("LEFT JOIN target_memberships ON targets.id = target_memberships.target_id")
        .where("target_memberships.target_id IS NULL").distinct
  }

  scope :has_any_keys, -> {
    joins("JOIN target_host_keys ON targets.id = target_host_keys.target_id")
        .where("target_host_keys.target_id IS NOT NULL").distinct
  }

  scope :has_not_any_keys, -> {
    joins("LEFT JOIN target_host_keys ON targets.id = target_host_keys.target_id")
        .where("target_host_keys.target_id IS NULL").distinct
  }

  #-- Validations

  validates :hostname, presence: true
  validates :hostname, :uniqueness => { case_sensitive: false, scope: [:partition_id, :proxy_id], message: 'dynamic target with same name already exists within partition and proxy scope' }
  validates :hostname, format: { with: /\A[a-z0-9.\-]+\z/, message: 'contains invalid characters'  }
  validate  :validate_hostname

  #-- Class Methods

  class << self

    def count_for_partition
      return 0 if User.current_user.partition.blank?
      TargetDynamic.where(partition: User.current_user.partition).count
    end

    def api_query_base
      self.includes([target_host_keys: [:target]]).order('targets.name ASC')
    end

  end

  #-- Instance Methods

  def icon
    'fa-asterisk'
  end

  def display_name_a
    [self.name_with_proxy, "(Dynamic by FQDN)"]
  end

  def display_type
    'Dynamic Target'
  end

  #-- Methods used by config API

  def target_host_keys=(values)
    update_target_host_keys(values)
  end

  def target_host_keys_add(values)
    values.each do |value|
      TargetHostKey.find_or_create_by(target_host: self, public_blob: SshKey.pubkey_without_comment(value[:public_blob])).validate!
    end
  end

  def target_host_keys_remove(values)
    values.each do |value|
      TargetHostKey.where(target_host: self, public_blob: SshKey.pubkey_without_comment(value[:public_blob])).destroy_all
    end
  end

  private

  def validate_hostname
    unless (proxy)
      errors.add('hostname', 'is not a fully qualified hostname including a domain') unless PublicSuffix.valid?(hostname, ignore_private: true)
    end
  end

  def before_validation_sanitize_hostname
    (self.name = self.name.strip.gsub(/[.]+$/,'').downcase rescue nil)
  end

end