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

class ClientAuthSet < ApplicationRecord

  include SwiftChangeTracker

  typed_store :properties, accessor: true, coder: Chef::JsonbCoder do |s|
    s.string  :comment
    s.string  :auth_logic
    s.string  :auth_logic_cached
    s.boolean :cache_enabled
    s.integer :cache_idle_time,  default: 7200
    s.integer :max_cache_time,   default: 43200
    s.boolean :cache_refresh,    default: true
    s.any     :cache_whitelist,  default: []
  end

  #-- Class methods
  class << self
    def auth_logic_collection
      [
        ['ANY (any method matches)', 'any'],
        ['ALL (all methods match)', 'all'],
        ['Public Key Method', 'publickey'],
        ['Interactive Method', 'interactive']
      ]
    end

    def all_collection
      ClientAuthSet.order("LOWER(name)").where(partition_id: User.current_user.partition.id).pluck(:name, :id)
    end

    def partition_default(partition_id)
      ClientAuthSet.where(partition_id: partition_id, system_int: true).first
    end
  end

  #-- Associations
  belongs_to :partition

  has_one :publickey_client_auth, -> { where category: 'publickey' }, class_name: 'ClientAuth', dependent: :destroy
  accepts_nested_attributes_for :publickey_client_auth, :allow_destroy => true

  has_one :interactive_client_auth, -> { where category: 'interactive' }, class_name: 'ClientAuth', dependent: :destroy
  accepts_nested_attributes_for :interactive_client_auth, :allow_destroy => true

  has_many :client_auths, dependent: :destroy

  has_many :profiles, dependent: :restrict_with_error
  has_many :bastion_profiles, dependent: :restrict_with_error

  #-- Validations

  validates :auth_logic, :inclusion => { :in => %w[all any publickey interactive], message: 'invalid auth logic' }
  validates :auth_logic_cached, :inclusion => { :in => %w[all any publickey interactive], message: 'invalid auth logic' }, :if => lambda { |cas| cas.cache_enabled }
  validates :cache_idle_time, format: { with: /\A\d+\z/, message: 'must be a integer' }
  validates :max_cache_time, format: { with: /\A\d+\z/, message: 'must be a integer' }
  validates :name, presence: true
  validates :name, uniqueness: { case_sensitive: false, scope: :partition_id, message: 'same name already exists within partition', allow_blank: false }

  validate :validate_at_least_one_client_auth
  validate :validate_auth_logic
  validate :validate_auth_logic_cached
  validate :validate_cache_whitelist

  #-- Callbacks

  #-- Initializer

  #-- Instance methods

  def cache_enabled=(value)
    v = ActiveModel::Type::Boolean.new.cast(value)
    self.auth_logic_cached = nil unless v
    super(v)
  end

  def cache_whitelist_text
    self.cache_whitelist.join("\n") rescue ''
  end

  def cache_whitelist_text=(values)
    self.cache_whitelist =
      values.split(/[ ,\n]/).map(&:strip).compact_blank.uniq.map { |ip| IPAddress(ip).network.to_string rescue ip }
  end

  def preferred_authentications
    self.client_auths.map { |auth| auth.preferred_authentications }.flatten.uniq.sort
  end

  def required_auths
    case self.auth_logic
      when 'any'
        []
      when 'all'
        [
          ('publickey' unless self.publickey_client_auth.blank?),
          self.interactive_client_auth&.required_auth
        ].compact_blank
      when 'publickey'
        ['publickey']
      when 'interactive'
        [self.interactive_client_auth&.required_auth || 'interactive']
      else
        raise StandardError, 'Unknown or missing auth logic'
    end
  end

  def required_auths_cached
    case self.auth_logic_cached
      when 'any'
        []
      when 'all'
        [
          ('publickey' unless self.publickey_client_auth.blank?),
          self.interactive_client_auth&.required_auth
        ].compact_blank
      when 'publickey'
        ['publickey']
      when 'interactive'
        [self.interactive_client_auth&.required_auth || 'interactive']
    else
      if self.cache_enabled
        raise StandardError, 'Unknown or missing auth logic'
      else
        []
      end
    end
  end

  def is_destroyable?
    return {false: 'Is provided by System'} if system_int
    return {false: 'Is assigned to a Bastion Profile'} if bastion_profiles.any?
    return {false: 'Is assigned to a Access Profile'} if profiles.any?

    { true: "Delete '#{self.name}'" } unless self.name.blank?
  end

  def auth_logic_human(cached: false)
    logic = if cached
      self.auth_logic_cached if self.cache_enabled
    else
      self.auth_logic
    end

    case logic
      when 'any'
        'ANY'
      when 'all'
        'ALL'
      when 'publickey'
        'Public Key'
      when 'interactive'
        'Interactive'
      else
        '-'
    end
  end

  def publickey_auth_properties
    unless self.publickey_client_auth.blank?
      { type: self.publickey_client_auth.type }
        .merge(self.publickey_client_auth.try(:properties))
        # prevents FalseClass to be rejected
        .reject { |_,v| v.to_s.blank? }
    else
      { type: 'none' }
    end
  end

  def interactive_auth_properties
    unless self.interactive_client_auth.blank?
      { type: self.interactive_client_auth.type }
        .merge(self.interactive_client_auth.try(:properties_with_defaults))
        # prevents FalseClass to be rejected
        .reject { |_,v| v.to_s.blank? }
    else
      { type: 'none' }
    end
  end

  def cache_properties
    if self.cache_enabled
      { cache:     :enabled,
        idle_time: self.cache_idle_time,
        max_time:  self.max_cache_time,
        refresh:   self.cache_refresh,
        whitelist: self.cache_whitelist
      }.reject { |_,v| v.blank? }
    else
      { cache: :disabled }
    end
  end

  private

  def validate_at_least_one_client_auth
    if self.publickey_client_auth.blank? or self.publickey_client_auth.marked_for_destruction?
      if self.interactive_client_auth.blank? or self.interactive_client_auth.marked_for_destruction?
        errors.add(:auth_logic, 'You have to select at least one Public Key or Interactive Authentication method below.')
       end
    end
  end

  def validate_auth_logic
    interactive_method_missing = self.interactive_client_auth.blank? || self.interactive_client_auth.marked_for_destruction?
    publickey_method_missing = self.publickey_client_auth.blank? || self.publickey_client_auth.marked_for_destruction?

    if %w[all any].include?(self.auth_logic) && (interactive_method_missing || publickey_method_missing)
      errors.add(:auth_logic, 'ALL any ANY require both, an Interactive and a Public Key Authentication method to be selected.')
    end

    if self.auth_logic == 'interactive'
      if interactive_method_missing
        errors.add(:auth_logic, 'Under Interactive Authentication, please select a method.')
      elsif self.interactive_client_auth.type == "ClientAuth::OpenidConnect"
        errors.add(:auth_logic, 'OpenID Connect requires ALL or ANY for compatibility reasons')
      end
    end

    if self.auth_logic == 'publickey' && publickey_method_missing
      errors.add(:auth_logic, 'Under Public Key Authentication, please select a method.')
    end
  end

  def validate_auth_logic_cached
    return unless self.cache_enabled

    interactive_method_missing = self.interactive_client_auth.blank? || self.interactive_client_auth.marked_for_destruction?
    publickey_method_missing = self.publickey_client_auth.blank? || self.publickey_client_auth.marked_for_destruction?

    # self.auth_logic_cached == 'all'
    %w[all any].include? self.auth_logic_cached
    if %w[all any].include?(self.auth_logic_cached) && (interactive_method_missing || publickey_method_missing)
      errors.add(:auth_logic_cached, 'ALL and ANY require both, an Interactive and a Public Key Authentication method to be selected.')
    end

    if self.auth_logic_cached == 'interactive' && interactive_method_missing
      errors.add(:auth_logic_cached, 'Under Interactive Authentication, please select a method.')
    end

    if self.auth_logic_cached == 'publickey' && publickey_method_missing
      errors.add(:auth_logic_cached, 'Under Public Key Authentication, please select a method.')
    end
  end

  def validate_cache_whitelist
    return if self.cache_whitelist.blank?

    self.cache_whitelist.each { |ip| IPAddress(ip) }
  rescue
    errors.add(:cache_whitelist_text, 'At least one IP address is invalid.')
  end

end
