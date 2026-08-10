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

class PartitionSetting < ApplicationRecord

  include SwiftChangeTracker

  #-- Datatypes

  #-- Associations
  belongs_to :partition, dependent: :destroy

  #-- Delegations
  delegate :name, to: :partition # Partition name instead of 'unknown' in Change Trail

  #-- Validations

  validate :validate_TargetPreferredAuthentications
  validate :validate_DnsSearchDomains
  validate :validate_ListenPorts
  validate :validate_DenyTargetAddresses
  validate :validate_GatewayAddresses
  validates :EmbryonicGraceTime,      inclusion: { in: 3..30, message: 'valid range is between 3 - 30, default is 10' }
  validates :LoginGraceTime,          inclusion: { in: 10..200, message: 'valid range is between 10 - 200, default is 120' }
  validates :MaxEmbryonics_start,     inclusion: { in: 10..100, message: 'valid range is 10 - 100, default is 30' }
  validates :MaxEmbryonics_rate,      inclusion: { in: 1..100,  message: 'valid range is 1 - 100, default is 10' }
  validates :MaxEmbryonics_max,       inclusion: { in: 20..200, message: 'valid range is 20 - 200, default is 100' }
  validates :ReportPeriod,            inclusion: { in: 30..1800, message: 'valid range is 30 - 1800, default is 900' }
  validates :TargetConnectionTimeout, inclusion: { in: 3..30, message: 'valid range is between 3 - 30, default is 20' }
  validates :MaxAuthFails,            inclusion: { in: 1..20, message: 'valid range is 3 - 20, default is 5' }
  validates :BlockAuthSeconds,        inclusion: { in: 60..86400, message: 'valid range is 60 - 86400, default is 900' }
  validates_length_of :PasswordSplitString, minimum: 1
  validates_length_of :ClientHostkeyAlgorithms, minimum: 1
  validates_length_of :TargetHostkeyAlgorithms, minimum: 1
  validates_length_of :ClientKexAlgorithms, minimum: 1
  validates_length_of :TargetKexAlgorithms, minimum: 1
  validates_length_of :ClientCiphers, minimum: 1
  validates_length_of :TargetCiphers, minimum: 1
  validates_length_of :ClientHmacs, minimum: 1
  validates_length_of :TargetHmacs, minimum: 1
  validates_numericality_of :MaxEmbryonics_max, greater_than: :MaxEmbryonics_start, message: 'must be greater than start value'

  #-- Class methods

  class << self

    def icon
      'fa-cube'
    end

    def client_authentication_collection
      [ ['Public Key', 'publickey'], ['Keyboard Interactive', 'keyboard-interactive'], ['Password', 'password'] ]
    end

    def target_authentication_collection
      [ ['Public Key - Gateway (or Proxy Individual) Identities', 'publickey'],
        ['Public Key - User SSH Auth Agent Forwarding *', 'publickey-ssh-agent'],
        ['Keyboard Interactive', 'keyboard-interactive'],
        ['Password', 'password'] ]
    end

    def ssh_hostkey_type_collection
      [['ED 25519 (256 bits)', 'ssh-ed25519'],
       ['ECDSA sha2-nistp-521 (521 bits)', 'ecdsa-sha2-nistp521'],
       ['ECDSA sha2-nistp-384 (384 bits)', 'ecdsa-sha2-nistp384'],
       ['ECDSA sha2-nistp-256 (256 bits)', 'ecdsa-sha2-nistp256'],
       ['RSA SHA2 (512 bits)', 'rsa-sha2-512'],
       ['RSA SHA2 (256 bits)', 'rsa-sha2-256'],
       ['RSA SHA1', 'ssh-rsa']]
    end

    def ssh_kex_algorithms_collection
      [
        ['Curve25519 SHA-2 (256 Bits)', 'curve25519-sha256'],
        ['Curve25519 SHA-2 (256 Bits) LibSSH', 'curve25519-sha256@libssh.org'],
        ['Diffie-Hellman Group-18 (8192 Bits), SHA2 (512 Bits)', 'diffie-hellman-group18-sha512'],
        ['Diffie-Hellman Group-16 (4096 Bits), SHA2 (512 Bits)', 'diffie-hellman-group16-sha512'],
        ['Diffie-Hellman Group-14 (2048 Bits), SHA2 (256 Bits)', 'diffie-hellman-group14-sha256'],
        ['Diffie-Hellman Group-Exchange, SHA2 (256 Bits)', 'diffie-hellman-group-exchange-sha256'],
        ['Diffie-Hellman Group-14 (2048 Bits), SHA1', 'diffie-hellman-group14-sha1'],
        ['Diffie-Hellman Group-1 (768 Bits), SHA1', 'diffie-hellman-group1-sha1'],
        ['Elliptic Curve Diffie-Hellman (ECDH) 521 Bits', 'ecdh-sha2-nistp521'],
        ['Elliptic Curve Diffie-Hellman (ECDH) 384 Bits', 'ecdh-sha2-nistp384'],
        ['Elliptic Curve Diffie-Hellman (ECDH) 256 Bits', 'ecdh-sha2-nistp256'],
        ['Hybrid Curve25519 + ML-KEM-768 (SHA-256)', 'mlkem768x25519-sha256'], # OpenSSL >= 3.5.0
        #['Hybrid NIST P-256 + ML-KEM-768 (SHA-256)', 'mlkem768nistp256-sha256'], # OpenSSL >= 3.5.0
        #['Hybrid NIST P-384 + ML-KEM-1024 (SHA-384)', 'mlkem1024nistp384-sha384'], # OpenSSL >= 3.5.0
        ['Hybrid Curve25519 + NTRU-Prime (SHA-512)', 'sntrup761x25519-sha512'],
        ['Hybrid Curve25519 + NTRU-Prime (SHA-512, OpenSSH)', 'sntrup761x25519-sha512@openssh.com']
      ]
    end

    def ssh_public_key_algorithms_collection
      [['ED 25519 (256 bits)', 'ssh-ed25519'],
       ['ECDSA sha2-nistp-521 (521 bits)', 'ecdsa-sha2-nistp521'],
       ['ECDSA sha2-nistp-384 (384 bits)', 'ecdsa-sha2-nistp384'],
       ['ECDSA sha2-nistp-256 (256 bits)', 'ecdsa-sha2-nistp256'],
       ['RSA SHA2 (512 bits)', 'rsa-sha2-512'],
       ['RSA SHA2 (256 bits)', 'rsa-sha2-256'],
       ['RSA SHA1', 'ssh-rsa']]
    end

    def hmacs_collection
      [['SHA2 (512 Bits, ETM)', 'hmac-sha2-512-etm@openssh.com'],
       ['SHA2 (256 Bits, ETM)', 'hmac-sha2-256-etm@openssh.com'],
       ['SHA1 (160 Bits, ETM)', 'hmac-sha1-etm@openssh.com'],
       ['SHA2 (512 Bits)', 'hmac-sha2-512'],
       ['SHA2 (256 Bits)', 'hmac-sha2-256'],
       ['SHA1 (160 Bits)', 'hmac-sha1']]
    end

    def af_collection
      [ ['any', 'any'], ['IPv4', 'ipv4'], ['IPv6', 'ipv6'] ]
    end

    def ciphers_collection
      [['AES-256-CTR (256 Bits, Counter)', 'aes256-ctr'],
       ['AES-256-CBC (256 Bits, Cipher-block chaining)', 'aes256-cbc'],
       #['AES-256-GCM (256 Bits, Galois/Counter)', 'aes256-gcm@openssh.com'], # Currently not supported by Net::SSH (suSSHi Remote Control)
       ['AES-192-CTR (192 Bits, Counter)', 'aes192-ctr'],
       ['AES-192-CBC (192 Bits, Cipher-block chaining)', 'aes192-cbc'],
       ['AES-128-CTR (128 Bits, Counter)', 'aes128-ctr'],
       ['AES-128-CBC (128 Bits,Cipher-block chaining)', 'aes128-cbc'],
       #['AES-128-GCM (128 Bits, Galois/Counter)', 'aes128-gcm@openssh.com'], # Currently not supported by Net::SSH (suSSHi Remote Control)
       ['Blowfish-CBC (Cipher-block chaining)', 'blowfish-cbc'],
       ['ChaCha20-Poly1305 (256 Bits, Counter)', 'chacha20-poly1305@openssh.com']]
    end

    def log_facility_collection
      %w(auth daemon security user local0 local1 local2 local3 local4 local5 local6 local7)
    end

    def config_params
      [ :AddressFamily, :AuditLogFile, :Banner,  :BlockAuthSeconds, :ClientCompression, :ClientTcpKeepalive, :ClientHostKeyUpdate,
        :EmbryonicGraceTime, :ExecLogFileMaxsize, :LoginGraceTime, :MaxAuthFails, :MaxEmbryonics,
        :PasswordSplitString, :PreserveClientBanner, :ReportPeriod,
        :SessionLogFile, :SessionLogFacility, :SystemLogFile, :SystemLogFacility,
        :TargetCiphers, :TargetCompression, :TargetConnectionTimeout, :TargetPassSusshiInformation,
        :TargetPreferredAddressFamily, :TargetTcpKeepAlive, :VerboseDisconnect,
        AllowedUserKeyTypes: [], PublicKeyAlgorithms: [],
        ClientCiphers: [], ClientHmacs: [], ClientHostkeyAlgorithms: [], DenyTargetAddresses: [], DnsSearchDomains: [], ExecLogStopPatterns: [],
        GatewayAddresses: [], HostKeys: [], ListenPorts: [], ListenAddresses: [], PreferredAuthentications: [],
        TargetCiphers: [], TargetHmacs: [], TargetHostkeyAlgorithms: [], TargetIdentityKeys: [], TargetPreferredAuthentications: [],
        ClientKexAlgorithms: [], TargetKexAlgorithms: []]
    end

    def configuration_keys
      PartitionSetting.config_params.collect {|x| x.class.to_s == 'Hash' ? x.keys : x }.flatten.collect{|x| x.to_s}
    end

  end

  #-- Callbacks
  before_validation :before_validation_remove_empty_array_fields
  before_validation :before_validation_sort_addresses

  #-- Instance methods

  def activate!
    self.update(state: 'active', state_num_changes: 0)
  end

  def susshid_identifiers
    self.partition.gateways.pluck(:susshid_identifier)
  end

  def swift_config_hash
    attributes.except('id', 'description', 'created_at', 'updated_at', 'partition_id', 'gateway_settings', 'MaxEmbryonics_start', 'MaxEmbryonics_rate', 'MaxEmbryonics_max')
              .merge({ 'MaxEmbryonics' => self.MaxEmbryonics }).compact.to_h
  end

  def DnsSearchDomainsBlob
    self.DnsSearchDomains.join("\n")
  end

  def DnsSearchDomainsBlob=(blob)
    self.DnsSearchDomains = blob.split(/[,\r\n ]/).uniq.reject{|d| d.blank?}.collect{|d| d.gsub(/[.]*$/,'')}
  end

  def MaxEmbryonics
    "#{self.MaxEmbryonics_start}:#{self.MaxEmbryonics_rate}:#{self.MaxEmbryonics_max}"
  end

  private

  #-- Custom validations

  def validate_TargetPreferredAuthentications
    if (self.TargetPreferredAuthentications.index('publickey-ssh-agent') || 100) < (self.TargetPreferredAuthentications.index('publickey') || -1)
      errors.add('TargetPreferredAuthentications', :invalid, message: "'Public Key - User SSH Auth Agent Forwarding' cannot be used before 'Public Key - Gateway (or Proxy Individual) Identities'.")
    end
  end

  def validate_DnsSearchDomains
    errors.add('DnsSearchDomainsBlob', :invalid, message: 'a maximum number of 100 DNS domains is supported') unless self.DnsSearchDomains.count <= 100
    self.DnsSearchDomains.each do |domain|
      errors.add('DnsSearchDomainsBlob', :invalid, message: "#{domain} is not a valid domain") unless PublicSuffix.valid?(domain, ignore_private: true)
    end
  end

  def validate_ListenPorts
    errors.add('ListenPorts', :invalid, message: 'please specify at least one listen port') unless self.ListenPorts.count > 0
    self.ListenPorts.each do |port|
      errors.add('ListenPorts', :invalid, message: 'valid range is between 22 - 65534') unless (22..65534).include?(port)
    end
  end

  def validate_DenyTargetAddresses
    self.DenyTargetAddresses.each do |ip|
      begin
        IPAddress(ip)
      rescue => e
        errors.add('DenyTargetAddresses', :invalid, message: e)
      end
    end
  end

  def validate_GatewayAddresses
    errors.add('GatewayAddresses', :invalid, message: 'please specify at least one trusted gateway address') unless self.GatewayAddresses.count > 0
    self.GatewayAddresses.each do |addr|
      errors.add('GatewayAddresses', "address #{addr} is invalid") if (IPAddress(addr) rescue nil).blank?
    end
  end

  #-- Callbacks

  def before_validation_sort_addresses
    self.DenyTargetAddresses.sort!
    self.GatewayAddresses.sort!
  end

  def before_validation_remove_empty_array_fields
    remove_blanks_and_dups(self.AllowedUserKeyTypes)
    remove_blanks_and_dups(self.ClientCiphers)
    remove_blanks_and_dups(self.ClientHostkeyAlgorithms)
    remove_blanks_and_dups(self.ClientHmacs)
    remove_blanks_and_dups(self.ClientKexAlgorithms)
    remove_blanks_and_dups(self.DnsSearchDomains)
    remove_blanks_and_dups(self.DenyTargetAddresses)
    remove_blanks_and_dups(self.ExecLogStopPatterns)
    remove_blanks_and_dups(self.GatewayAddresses)
    remove_blanks_and_dups(self.ListenPorts)
    remove_blanks_and_dups(self.ListenAddresses)
    remove_blanks_and_dups(self.PreferredAuthentications)
    remove_blanks_and_dups(self.PublicKeyAlgorithms)
    remove_blanks_and_dups(self.TargetCiphers)
    remove_blanks_and_dups(self.TargetHostkeyAlgorithms)
    remove_blanks_and_dups(self.TargetHmacs)
    remove_blanks_and_dups(self.TargetKexAlgorithms)
    remove_blanks_and_dups(self.TargetPreferredAuthentications)
  end

  def remove_blanks_and_dups(object)
    object.reject!(&:blank?)
    object.uniq!
    object.compact!
  end

end
