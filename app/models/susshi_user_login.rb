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

class SusshiUserLogin < SusshiUser
  #-- Datatypes

  alias_attribute :username, :name

  store_accessor :properties, [
    :totp_state,
    :totp_consumed_timestamp,
    :totp_secret,
    :totp_activation_token,
    :auth_fails,
    :last_auth_fail_at
  ]

  #-- Associations
  has_many :susshi_user_memberships, dependent: :destroy
  has_many :susshi_user_groups, -> { distinct }, through: :susshi_user_memberships,
           after_add: :after_add_relation, after_remove: :after_remove_relation

  has_many :susshi_user_keys, dependent: :destroy,
           after_add: :after_add_relation, after_remove: :after_remove_relation

  accepts_nested_attributes_for :susshi_user_keys, :allow_destroy => true

  has_many :target_host_keys, dependent: :destroy

  has_many :group_accesses, -> { distinct }, through: :susshi_user_groups, source: :accesses
  has_many :group_bastions, -> { distinct }, through: :susshi_user_groups, source: :bastions

  #-- Scopes

  scope :has_any_memberships, -> {
    joins("JOIN susshi_user_memberships ON susshi_users.id = susshi_user_memberships.susshi_user_login_id")
        .where("susshi_user_memberships.susshi_user_login_id IS NOT NULL").distinct
  }

  scope :has_not_any_memberships, -> {
    joins("LEFT JOIN susshi_user_memberships ON susshi_users.id = susshi_user_memberships.susshi_user_login_id")
        .where("susshi_user_memberships.susshi_user_login_id IS NULL").distinct
  }

  scope :has_any_keys, -> {
    joins("JOIN susshi_user_keys ON susshi_users.id = susshi_user_keys.susshi_user_login_id")
        .where("susshi_user_keys.susshi_user_login_id IS NOT NULL").distinct
  }

  scope :has_not_any_keys, -> {
    joins("LEFT JOIN susshi_user_keys ON susshi_users.id = susshi_user_keys.susshi_user_login_id")
        .where("susshi_user_keys.susshi_user_login_id IS NULL").distinct
  }

  def self.totp_states
    %w(inactive active activation_pending)
  end

  #-- Validations
  validates :username, :presence => true
  validates :username, :uniqueness => { case_sensitive: false, scope: :partition_id, message: 'gateway user with same name already exists within partition' }
  validates :username, exclusion: { in: %w(ALL), message: 'ALL is a reserved keyword' }
  validates :username, format: { with: /\A[a-zA-Z0-9._\-]+\z/, message: 'contains invalid characters' }
  validates :fullname, :presence => true
  validates :password, confirmation: true, if: -> { self.password_changed? }
  validates :password_confirmation, presence: true, if: -> { self.password_changed? }
  validates :totp_state, inclusion: { in: SusshiUserLogin.totp_states }
  validates :totp_activation_token, :presence => true, if: Proc.new { |r| r.totp_state == 'activation_pending' }
  validates :totp_activation_token, length: { is: 64, message: 'must be 64 characters long', allow_blank: true }
  validates :totp_secret, :presence => true, if: Proc.new { |r| r.totp_state == 'active' }
  validates :totp_secret, length: { is: 32, message: 'must be 32 characters long', allow_blank: true }

  #-- Callbacks
  before_validation :before_validation_sanitize_username
  before_validation :before_validation_sanitize_totp
  before_save :hash_new_password, if: -> { self.password_changed? }

  #-- Class Methods

  class << self

    def count_for_partition
      return 0 if User.current_user.partition.blank?
      SusshiUserLogin.where(partition: User.current_user.partition).count
    end

    def duallist_collection(partition_id)
      SusshiUserLogin.where(partition_id: partition_id).order("LOWER(name) ASC").all.pluck(:name, :fullname, :id)
          .collect{|t| ["#{t.first} (#{t.second})", t.last]}
    end

    def skip_attributes_in_swift_log
      %w[email fullname]
    end

    def api_query_base
      self.includes([:susshi_user_groups, :susshi_user_keys]).order('susshi_users.name ASC')
    end

    def clear_statistics
      SusshiUserLogin.all.update_all(use_count: 0, first_use_at: nil, last_use_at: nil)
    end

    def totp_collection(state)
      [
        [ "Keep current state (#{state.humanize})", 'keep'],
        # Currently unused, commented out to avoid confusion
        # ['Create new TOTP activation code', 'activate'],
        # ['Create new TOTP secret', 'secret'],
        ['Create and activate new TOTP credentials', 'secret'],
        ['Deactivate and remove TOTP credentials', 'deactivate' ]
      ]
    end

  end

  #-- Instance Methods

  def icon
    'fa-user'
  end

  #-- Methods used by config API
  def memberships
    self.susshi_user_groups.pluck(:name)
  end

  def memberships=(values)
    self.susshi_user_groups = SusshiUserGroup.query_by_ids_or_names('memberships', self.partition_id, values)
  end

  def memberships_add(values)
    self.susshi_user_groups << SusshiUserGroup.query_by_ids_or_names('memberships', self.partition_id, values, self.susshi_user_groups)
  end

  def memberships_remove(values)
    self.susshi_user_groups.delete SusshiUserGroup.query_by_ids_or_names('memberships', self.partition_id, values)
  end

  def susshi_user_keys=(values)
    wants = values.map do |s|
      raise SshKey::PublicKeyError, 'invalid key' unless SshKey.valid_ssh_public_key?(s[:public_blob])
      { title: s[:title], public_blob: SshKey.pubkey_without_comment(s[:public_blob]) }
    end
    haves = self.susshi_user_keys.map { |s| { id: s.id, title: s.title, public_blob: s.public_blob } }

    haves.each do |have|
      if wants.include?(have.except(:id))
        wants.delete(have.except(:id))
      else
        self.susshi_user_keys.find(have[:id]).destroy
      end
    end
    wants.each do |want|
      self.susshi_user_keys.build({title: want[:title], public_blob: want[:public_blob]})
    end
  end

  def susshi_user_keys_add(values)
    values.each do |value|
      key = SusshiUserKey.where(susshi_user_login: self).where('public_blob = ? OR title = ?', SshKey.pubkey_without_comment(value[:public_blob]), value[:title])
      SusshiUserKey.create(susshi_user_login: self, public_blob: value[:public_blob], title: value[:title]) unless key.any?
    end
  end

  def susshi_user_keys_remove(values)
    values.each do |value|
      SusshiUserKey.where(susshi_user_login: self).where('public_blob = ? OR title = ?', SshKey.pubkey_without_comment(value[:public_blob]), value[:title]).destroy_all
    end
  end

  def valid_password?(user_password)
    if (terms = self.password.split('$') rescue []).size == 4
      self.password == "$6$#{terms[2]}$#{Digest::SHA512.hexdigest("#{terms[2]}#{user_password}")}"
    else
      false
    end
  end

  #--- TOTP methods

  def generate_totp_activation_token!
    reset_totp_attributes
    self.totp_activation_token = SecureRandom.hex(32)
    self.totp_state = 'activation_pending'
    save
  end

  def generate_totp_secret!
    reset_totp_attributes
    self.totp_secret = ROTP::Base32.random_base32(32)
    self.totp_state = 'active'
    save
  end

  def activate_totp(activation_token)
    raise Errors::Totp::ActivationError, 'No TOTP activation pending.' if self.totp_state != 'activation_pending'
    raise Errors::Totp::ActivationError, 'No TOTP activation token found.' if self.totp_activation_token.blank?
    raise Errors::Totp::ActivationError, 'TOTP activation token wrong.' if activation_token != self.totp_activation_token
    generate_totp_secret!
  end

  def verify_totp!(totp_code)
    last_otp_at = self.totp.verify(totp_code, after: (self.totp_consumed_timestamp||0).to_i, drift_behind: 30)
    raise Errors::Totp::Verification if last_otp_at.blank?

    self.totp_consumed_timestamp = last_otp_at
    save
  end

  def deactivate_totp!
    reset_totp_attributes
    save
  end

  def totp_qr_image
    RQRCode::QRCode.new(totp_uri).as_png(size: 240, border_modules: 0)
  end

  def totp_uri
    if self.totp_state == "active"
      issuer = Preference.first.frontend_totp_issuer&.gsub(/[[:blank:]]/, "%20")
      "otpauth://totp/#{self.username}?secret=#{self.totp_secret}&issuer=#{issuer}"
    end
  end

  private

  def hash_new_password
    return if self.password.blank?
    salt = SecureRandom.hex(4)
    self.password = "$6$#{salt}$#{Digest::SHA512.hexdigest("#{salt}#{self.password}")}"
  end

  def before_validation_sanitize_username
    (self.username = self.username.strip.gsub(/[.]+$/,'').downcase rescue nil)
  end

  def before_validation_sanitize_totp
    # if totp_secret is set by API, we adjust totp_state
    if totp_secret_changed?
      self.totp_state = 'active' unless self.totp_secret.blank?
    else
      if totp_activation_token_changed?
        self.totp_state = 'activation_pending' unless self.totp_activation_token.blank?
      end
    end

    case totp_state
      when 'inactive'
        reset_totp_attributes
      when 'active'
        self.properties.delete('totp_activation_token')
      when 'activation_pending'
        self.properties.delete('totp_secret')
    end

    if totp_state_changed?
      case totp_state
        when 'active'
          generate_totp_secret! unless totp_secret_changed?
        when 'activation_pending'
          generate_totp_activation_token! unless totp_activation_token_changed?
      end
    end
  end

  def totp
    raise Errors::Totp::Any, 'TOTP not active for user' if self.totp_state != 'active'
    ROTP::TOTP.new(self.totp_secret)
  end

  def reset_totp_attributes
    self.properties.delete('totp_activation_token')
    self.properties.delete('totp_consumed_timestamp')
    self.properties.delete('totp_secret')
    self.totp_state = 'inactive'
  end

end