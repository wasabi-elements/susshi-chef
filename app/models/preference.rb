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

class Preference < ApplicationRecord
  encrypts :smtp_settings

  #-- Associations
  has_many :binary_stores, :as => :attached, :dependent => :destroy
  has_one :sic_ca_certificate, -> { where kind: 'sic_ca_certificate', format: 'application/x-pem-file'}, as: :attached, class_name: 'BinaryStore', dependent: :destroy
  has_one :sic_ca_key, -> { where kind: 'sic_ca_key', format: 'application/x-pem-file' }, as: :attached, class_name: 'BinaryStore', dependent: :destroy

  has_one :sic_api_certificate, -> { where kind: 'sic_api_certificate', format: 'application/x-pem-file'}, as: :attached, class_name: 'BinaryStore', dependent: :destroy
  has_one :sic_api_key, -> { where kind: 'sic_api_key', format: 'application/x-pem-file' }, as: :attached, class_name: 'BinaryStore', dependent: :destroy

  # Server Key / Certificate in creation
  has_one :server_key, -> { where kind: 'server_key', format: 'application/x-pem-file' }, as: :attached, class_name: 'BinaryStore', dependent: :destroy
  has_one :server_csr, -> { where kind: 'server_csr', format: 'application/x-pem-file'}, as: :attached, class_name: 'BinaryStore', dependent: :destroy
  has_one :server_certificate, -> { where kind: 'server_certificate', format: 'application/x-pem-file' }, as: :attached, class_name: 'BinaryStore', dependent: :destroy

  # Server Key / Certificate active
  has_one :active_server_key, -> { where kind: 'active_server_key', format: 'application/x-pem-file' }, as: :attached, class_name: 'BinaryStore', dependent: :destroy
  has_one :active_server_certificate, -> { where kind: 'active_server_certificate', format: 'application/x-pem-file'}, as: :attached, class_name: 'BinaryStore', dependent: :destroy

  # Alternative Key / Certificate if no user-provided Server Key / Certificate exists.
  has_one :alt_server_key, -> { where kind: 'alt_server_key', format: 'application/x-pem-file' }, as: :attached, class_name: 'BinaryStore', dependent: :destroy
  has_one :alt_server_certificate, -> { where kind: 'alt_server_certificate', format: 'application/x-pem-file'}, as: :attached, class_name: 'BinaryStore', dependent: :destroy

  #-- Datatypes

  typed_store :smtp_settings do |t|
    t.string :smtp_address
    t.integer :smtp_port, default: 25
    t.string :smtp_domain
    t.string :smtp_from
    t.string :smtp_user_name
    t.string :smtp_password
    t.string :smtp_authentication
    t.string :smtp_encryption
    t.integer :smtp_openssl_verify_mode, default: OpenSSL::SSL::VERIFY_PEER
  end

  #-- Validators

  validates :max_session_time, presence: true, numericality: true
  validates :max_session_time, inclusion: { in: 600..86400, message: 'range of 600 to 86400 is valid' }

  validates :max_idle_time, presence: true, numericality: true
  validates :max_idle_time, inclusion: { in: 300..86400, message: 'range of 300 to 86400 is valid' }

  validates :password_length, presence: true, numericality: true
  validates :password_length, inclusion: { in: 8..20 }

  validates :password_archiving_count, presence: true, numericality: true
  validates :password_archiving_count, inclusion: { in: 0..12 }

  validates_numericality_of :max_idle_time, less_than: :max_session_time, message: 'must be less than max session time'

  validates :syslog_proto, inclusion: %w(udp tcp relp), allow_blank: true
  validates :syslog_port, numericality: {only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 65535, allow_blank: true}
  validates :syslog_server1, format: { with: /\A[a-zA-Z0-9._:\-]+\z/, message: 'contains invalid characters', allow_blank: true }
  validates :syslog_server2, format: { with: /\A[a-zA-Z0-9._:\-]+\z/, message: 'contains invalid characters', allow_blank: true }
  validates :syslog_server3, format: { with: /\A[a-zA-Z0-9._:\-]+\z/, message: 'contains invalid characters', allow_blank: true }
  validates :syslog_server4, format: { with: /\A[a-zA-Z0-9._:\-]+\z/, message: 'contains invalid characters', allow_blank: true }

  validates :admin_auth_realm, presence: true
  validates :admin_auth_realm, format: { with: /\A[a-zA-Z0-9._\- ]+\z/, message: 'contains invalid characters'  }

  validates :ui_ssl_client_cert_verify_depth, inclusion: { in: 1..10 }
  validate :validate_ui_ssl_client_settings

  validates :frontend_totp_issuer, presence: true
  validates :frontend_totp_issuer, length: { in: 3..32, message: 'must be between 3 and 32 characters long' }
  validates :frontend_totp_issuer, format: { with: /\A[A-Za-z0-9 .,=_&#+!\\\/()\[\]-]+\z/, message: 'contains characters not allowed' }

  validates :smtp_port, inclusion: { in: 1..65535, message: 'range of 1 to 65535 is valid' }, unless: Proc.new { self.smtp_port.blank? }
  validates :smtp_from, presence: true, unless: Proc.new { self.smtp_address.blank? }

  #-- Callbacks

  before_save :sanitize_smtp_settings

  after_update_commit :after_update_update_devise_settings
  after_update_commit :after_update_update_users_otp
  after_update_commit :after_update_run_commands

  #-- Class variables

  @@installation_identifier = nil

  #-- Class methods

  class << self

    def instance
      Preference.first_or_initialize
    end

    def installation_id_valid?(comp_id)
      Preference.first.installation_identifier == comp_id rescue false
    end

    def certificate_info(cert)
      if cert.blank?
        '- missing -'
      else
        cert = OpenSSL::X509::Certificate.new( cert.data )
        [ [ 'Key-ID', cert.extensions.select{|a| a.to_a.first == 'subjectKeyIdentifier'}.first.to_s.split('=').last ],
          [ 'Valid until', cert.not_after ] ].collect{|key,value| "#{key}: #{value}"}.join('/br')
      end
    end

    def csr_info(csr)
      if csr.blank?
        '- missing -'
      else
        cert = OpenSSL::X509::Request.new( csr.data )
        [ [ 'Test', 'test' ],
          [ 'Valid until', cert.not_after ] ].collect{|key,value| "#{key}: #{value}"}.join('/br')
      end
    end

    def expire_password_after_collection
      [ ['Never expire', 0], ['1 Month', 1.month], ['2 Months', 2.months], ['3 Months', 3.months], ['4 Months', 4.months],  ['5 Months', 5.months],  ['6 Months', 6.months], ['1 Year', 1.year] ]
    end

    def password_archiving_count_collection
      [ ['No Password history', 0], ['1 Password', 1], ['2 Passwords', 2], ['3 Passwords', 3], ['4 Passwords', 4], ['5 Passwords', 5], ['6 Passwords', 6],
        ['7 Passwords', 7], ['8 Passwords', 8], ['9 Passwords', 9], ['10 Passwords', 10], ['11 Passwords', 11], ['12 Passwords', 12] ]
    end

    def password_length_collection
      (8..20).map {|l| ["#{l} Characters", l]}
    end

    def admin_auth_method_collection
      if totp_secret_key_set?
        [ ['Password', 'password'], ['Password + One-Time Password (time-based OATH-TOTP)', 'password-otp'] ]
      else
        [ ['Password', 'password'] ]
      end
    end

    def otp_url(user)
      app_name = URI.encode_www_form_component(Preference.first.admin_auth_realm)
      issuer = Preference.first.admin_auth_realm&.gsub(/[[:blank:]]/, "%20")
      "otpauth://totp/#{app_name}:#{user.email}?secret=#{user.otp_secret}&issuer=#{issuer}"
    end


    # Called from config/environment.rb on application initialization and from after_commit callback of this model
    def update_devise_settings!
      begin
        p = Preference.first
        Devise.expire_password_after = p.expire_password_after > 0 ? p.expire_password_after : false

        if p.password_archiving_count > 0
          Devise.password_archiving_count = p.password_archiving_count
          Devise.deny_old_passwords = true
        else
          Devise.password_archiving_count = 0
          Devise.deny_old_passwords = false
        end
      rescue
      end
    end

    def totp_secret_key_set?
      !ENV['CHEF_MASTER_KEY'].blank?
    end

    def frontend_totp_available?
      totp_secret_key_set?
    end

    def frontend_totp_show_on_ui?
      totp_secret_key_set? and Preference.first.frontend_totp_show_uri
    end

    def frontend_totp_show_on_api?
      totp_secret_key_set? and Preference.first.frontend_totp_show_uri_on_api
    end

    def installation_identifier
      if @@installation_identifier.nil?
        @@installation_identifier = Preference.first.try(:installation_identifier)
      end

      @@installation_identifier
    end

    def action_mailer_setup?
      return false if Preference.none?

      ! Preference.first.smtp_address.blank?
    end
  end

  #-- Instance methods

  def get_max_session_time
    self.max_session_time > 0 ? self.max_session_time : 24.hours.to_i
  end

  def get_max_idle_time
    self.max_idle_time > 0 ? self.max_idle_time : 24.hours.to_i
  end

  def get_certificate_info
    Preference.certificate_info(self.server_certificate)
  end

  def get_csr_info
    Preference.csr_info(self.server_csr)
  end

  def otp_active?
    self.admin_auth_method == 'password-otp'
  end

  private

  def after_update_update_devise_settings
    Preference.update_devise_settings!
  end

  def after_update_update_users_otp
    return if saved_changes["admin_auth_method"].blank?
    User.all.each do |user|
      if otp_active?
        user.enable_otp
      else
        user.disable_otp
      end
    end
  end

  def after_update_run_commands
    Rsyslog::Daemon.restart
    LogRetention.purge_session_reports
    LogRetention.purge_system_events
  end

  def sanitize_smtp_settings
    if self.smtp_address.blank?
      self.smtp_settings = {}
    else
      if self.smtp_authentication.blank?
        self.smtp_user_name = nil
        self.smtp_password = nil
      end
    end

    self.smtp_settings.compact_blank!
  end

  def validate_ui_ssl_client_settings
    if self.ui_ssl_client_cert_verify == true
      if self.ui_ssl_client_cert_ca.blank?
        errors.add(:ui_ssl_client_cert_ca, "can't be blank")
      end
      if self.ui_ssl_client_cert_cn_pattern.blank?
        errors.add(:ui_ssl_client_cert_cn_pattern, "can't be blank")
      end
    end
    unless self.ui_ssl_client_cert_ca.blank?
      unless SSL::Server.is_valid_certificate?(self.ui_ssl_client_cert_ca)
        errors.add(:ui_ssl_client_cert_ca, "invalid format")
      end
    end
  end

end
