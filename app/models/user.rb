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

class User < ApplicationRecord
  devise :two_factor_authenticatable

  encrypts :log_encryption_key

  #-- Devise
  devise :timeoutable, :trackable, :validatable,
         :password_expirable, :password_archivable,
         :authentication_keys => [:username]

  #-- Datatypes

  #-- Associations

  has_and_belongs_to_many :partitions
  belongs_to :default_partition, :class_name => 'Partition', optional: true

  #-- Scopes
  default_scope { order('username ASC') }

  #-- Callbacks

  before_validation :sanitize_log_encryption_key
  after_create_commit :after_create_enable_otp

  #-- Validations

  validates :username, :presence => true
  validates :username, :length => { :in => 5..32, :message => 'username should be somewhat between 5 and 32 characters' }
  validates :username, :format => { :with => /\A[a-zA-Z0-9._-]+\z/, :message => 'only letters and numbers are allowed' }
  validates :username, :uniqueness => { :case_sensitive => false, :message => 'same username already exists' }

  # At least 8 characters, at least 1 digit, at least 1 lowercase alphabet, at least 1 uppercase alphabet, at least 1 special char in the set given
  validate  :validate_password_length
  validates :password, :format => { :with => /\A.*(?=.{8,})(?=.*\d)(?=.*[a-z])(?=.*[A-Z])(?=.*[[:punct:]]).*\z/, :allow_blank => true, :message => 'please use a stronger password with at least 1 digit, at least 1 lowercase alphabet, at least 1 uppercase alphabet, at least 1 special character' }

  validates :fullname, :presence => true

  validate :validate_log_encryption_key

  #-- Public attributes

  alias_attribute :name, :fullname

  #-- Class Methods

  class << self

    def roles
      {
          super:    { includes: [:super, :admin, :readonly], title: 'Super-Admin', color: 'danger' },
          admin:    { includes: [:admin, :readonly], title: 'Partition Admin', color: 'primary' },
          readonly: { includes: [:readonly], title: 'Partition Read-Only', color: 'navy' },
      }
    end

    def roles_collection
      User.roles.collect{|key, value| [ value[:title], key ] }
    end

    def current_user=(user)
      RequestStore.store[:current_user] = user
    end

    def current_user
      RequestStore.store[:current_user]
    end

    def last_activity
      RequestStore.store[:last_activity]
    end

    def last_activity=(activity)
      RequestStore.store[:last_activity] = activity
    end

    def selector_collection_for_search
      User.all.map { |u| [ u.fullname, u.username ] }
    end

    def selector_collection
      User.select([:username, :fullname, :id]).order(:username).all.map { |user| [ "#{user.username} -- #{user.fullname}", user.id ] }
    end

    def partition=(partition)
      RequestStore.store[:partition] = partition
      RequestStore.store[:partition]
    end

    def partition
      RequestStore.store[:partition]
    end

    def set_partition_by_id(part_id)
      unless (RequestStore.store[:partition].id rescue nil) == part_id
        RequestStore.store[:partition] = User.current_user.partitions.find(part_id) rescue nil
        RequestStore.store[:partition]
      end
    end

    def any_log_encryption_recipient?
      return false unless Subscription.instance.feature_audit_log_encryption?
      User.where.not(log_encryption_key: [nil, ""]).count > 0
    end

  end

  #-- Instance Methods

  def get_role
    self.role.to_sym
  end

  def get_role_color
    User.roles[self.role.to_sym][:color] rescue 'default'
  end

  def get_role_title
    User.roles[self.role.to_sym][:title] rescue 'Unknown'
  end

  def roles
    User.roles[self.role.to_sym][:includes] rescue []
  end

  def has_any_role?
    roles.count > 0
  end

  def has_role_readonly?
    roles.include?(:readonly)
  end

  def has_role_admin?
    roles.include?(:admin)
  end

  def has_role_super?
    roles.include?(:super)
  end

  def is_log_encryption_recipient?
    self.log_encryption_key.present?
  end

  def has_role_read_partition?(partition)
    return true if roles.include?(:super)
    roles.include?(:readonly) && self.partitions.include?(partition)
  end

  def has_role_admin_partition?(partition)
    return true if roles.include?(:super)
    roles.include?(:admin) && self.partitions.include?(partition)
  end

  def access_permitted?(controller, level)
    return true
  end

  def menu_accessible?(controller)
    return true
  end

  def partition
    if User.partition.blank?
      User.partition ||= (self.partitions.pluck(:id).include?(self.default_partition_id) ? self.default_partition : nil)
      User.partition ||= self.partitions.first
    end
    User.partition
  end

  def timeout_in
    #     if (Time.now > ((self.last_activity_at || Time.now) + Preference.first.get_max_idle_time))
    if (false)
      0.seconds
    else
      # self.update_column(:last_activity_at, Time.now)
      Preference.first.get_max_session_time.seconds
    end
  end

  def is_destroyable?
    return {true: 'Delete Administrative User'} if self.role != 'super'
    if User.where(role: 'super').count < 2
      {false: 'You would loose last Super-Admin if you remove this user'}
    else
      {true: 'Delete Administrative User'}
    end
  end

  def minimum_password_length
    Preference.first.password_length
  end

  def enable_otp
    reset_otp_attributes
    self.update(otp_activation_token: SecureRandom.hex(32))
  end

  def generate_otp_secret
    self.update(otp_secret: User.generate_otp_secret)
  end

  def activate_otp
    self.update(otp_required_for_login: true, otp_activation_token: "")
  end

  def disable_otp
    reset_otp_attributes
  end

  def validate_otp_activation(otp_activation)
    otp_activation == self.otp_activation_token
  end

  def otp_qr_image
    RQRCode::QRCode.new(otp_url).as_png(size: 300)
  end

  def otp_url
    Preference.otp_url(self)
  end

  private

  def validate_password_length
    return if password.blank?
    unless password.size >= minimum_password_length
      errors.add(:password, "please use a longer password with a minimum of #{minimum_password_length} characters")
    end
  end

  def validate_log_encryption_key
    return if log_encryption_key.blank?
    unless SshKey.valid_ssh_public_key?(log_encryption_key) && log_encryption_key.match(/^ssh-ed25519 /)
      errors.add(:log_encryption_key, "This is not a valid ED25519 SSH public key.")
    end
  end

  def sanitize_log_encryption_key
    self.log_encryption_key = nil if log_encryption_key.blank?
    if log_encryption_key&.match(/^ssh-ed25519\s+[A-Za-z0-9+\/]+=*(\s+.*)?$/)
      self.log_encryption_key = log_encryption_key.split[0..1].join(" ").strip
    end
  end

  def reset_otp_attributes
    self.update(otp_required_for_login: false, otp_activation_token: nil, consumed_timestep: 0)
  end

  def after_create_enable_otp
    return unless Preference.first.otp_active?
    if self.otp_activation_token.blank? and otp_secret.blank?
      self.update_columns(otp_activation_token: SecureRandom.hex(32))
    end
  end

end
