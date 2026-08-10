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

class Gateway < ApplicationRecord
  encrypts :sic_psk

  include SwiftChangeTracker

  belongs_to :partition

  #-- Callbacks

  before_validation :before_validation_fill_susshid_identifier
  after_commit :after_commit_update_sic_and_partition_settings, on: [:create, :update]

  #--- Relations

  has_many :binary_stores, :as => :attached, :dependent => :destroy

  has_one :sic_certificate, -> { where kind: 'sic_certificate', format: 'application/x-pem-file' }, as: :attached, class_name: 'BinaryStore', dependent: :destroy
  has_one :sic_key, -> { where kind: 'sic_key', format: 'application/x-pem-file' }, as: :attached, class_name: 'BinaryStore', dependent: :destroy

  has_one :sic_ssh_private_key, -> { where kind: 'sic_ssh_private_key', format: 'application/x-pem-file' }, as: :attached, class_name: 'BinaryStore', dependent: :destroy
  has_one :sic_ssh_public_key, -> { where kind: 'sic_ssh_public_key', format: 'application/x-pem-file' }, as: :attached, class_name: 'BinaryStore', dependent: :destroy

  # Syslog Certificate
  has_one :syslog_certificate, -> { where kind: 'syslog_certificate', format: 'application/x-pem-file'}, as: :attached, class_name: 'BinaryStore', dependent: :destroy
  has_one :syslog_key, -> { where kind: 'syslog_key', format: 'application/x-pem-file' }, as: :attached, class_name: 'BinaryStore', dependent: :destroy

  #-- Validations

  validates :name, presence: true
  validates :name, format: { with: /\A[a-zA-Z0-9-]+\z/, message: "only letters, numbers and '-' are allowed" }
  validates :name, uniqueness: { scope: :partition_id, case_sensitive: false, message: 'same hostname already exists within partition' }

  validates :susshid_identifier, presence: true
  validates :susshid_identifier, length: { in: 4..4, message: 'susshid identifier must be 4 characters long' }
  validates :susshid_identifier, format: { with: /\A[a-z0-9]+\z/, message: 'only lowercase letters and numbers are allowed' }
  validates :susshid_identifier, uniqueness: { case_sensitive: false,
                                               message: Proc.new { |error, attributes|
                                                 'Identifier must be uniq throughout all partitions.' +
                                                     ' Already used identifiers are: ' +
                                                     "#{Gateway.pluck(:susshid_identifier).join(', ')}."
                                               } }

  validates :sic_host, uniqueness: { scope: [:sic_port, :partition_id], allow_blank: true, message: 'host:port must be uniq within partition' }
  validates :sic_port, presence: true
  validates :sic_port, inclusion: { in: 22..65534, message: 'port must be in range 22..65534' }

  validate :validate_ip_addresses

  #-- Class methods

  class << self

    def icon
      'fa-dungeon'
    end

    def restart_required?(partition, swift_version = nil)
      swift_version ||= partition.current_swift_version
      klasses = %w[Gateway Partition PartitionAuthKey PartitionHostKey PartitionSetting Proxy]

      partition.swift_changes.exists?(klass: klasses, swift_version:)
    end

    def next_identifier
      "%04d" % ((Gateway.pluck(:susshid_identifier).sort{|x,y| x<=>y}.last.to_i rescue 0)+1).to_s
    end

    def renew_sic_certificates(enforce: false)
      Gateway.where.not(ssl_client_fingerprint: nil).each do |gateway|
        renew = enforce ||
          Time.now >= gateway.sic_certificate_not_before + ENV['SIC_CERTS_EXPIRY_DAYS'].to_i.days ||
            Time.now >= gateway.sic_certificate_not_after - ENV['SIC_CERTS_EXPIRY_DAYS'].to_i.days

        if renew
          result = gateway.renew_sic_certificate
          puts "[#{Time.now}] Gateway #{gateway.susshid_identifier} - #{gateway.name}: #{result}"
        else
          puts "[#{Time.now}] Gateway #{gateway.susshid_identifier} - #{gateway.name}: no update needed, certificate expires in about #{(gateway.sic_certificate_not_after.to_date - Time.now.to_date).round} days."
        end
      end
    end

  end

  #-- Instance methods

  def create_sic_certificate
    SSL::Sic.create_sic_certificate(self)
  end

  def create_syslog_certificate
    SSL::Sic.create_syslog_certificate(self)
  end

  def sic_certificate_key_id
    return '- missing -' if self.sic_certificate.blank?

    cert = OpenSSL::X509::Certificate.new(self.sic_certificate.data)
    cert.extensions.find { |ext| ext.to_a.include? "subjectKeyIdentifier" }&.value
  end

  def sic_certificate_not_after
    return '- missing -' if self.sic_certificate.blank?
    OpenSSL::X509::Certificate.new(self.sic_certificate.data).not_after
  end

  def sic_certificate_not_before
    return '- missing -' if self.sic_certificate.blank?
    OpenSSL::X509::Certificate.new(self.sic_certificate.data).not_before
  end

  def sic_certificate_info
    if self.sic_certificate.blank?
      '- missing -'
    else
      cert = OpenSSL::X509::Certificate.new(self.sic_certificate.data)
      "Key-ID: #{cert.extensions.select { |a| a.to_a.first == 'subjectKeyIdentifier' }.first.to_s.split('=').last}</br>Valid until #{cert.not_after}."
    end
  end

  def sic_certificate_fingerprint
    if self.sic_certificate.blank?
      '- missing -'
    else
      OpenSSL::Digest::SHA1.new(OpenSSL::X509::Certificate.new(self.sic_certificate.data).to_der).to_s
    end
  end

  def create_sic_ssh_key
    k = SSHKey.generate(type: "RSA", bits: 2048, comment: "Chef Remote Control")

    self.create_sic_ssh_private_key!(data: k.encrypted_private_key)
    self.create_sic_ssh_public_key!(data: k.ssh_public_key)
  end

  def renew_sic_certificate
    self.transaction do
      create_sic_certificate
      create_syslog_certificate
      Swift::Updater::Gateway.swift_update(partition_id)
    end

    result = Susshid::RemoteControl.restart(id)['return'] rescue 'failed'
    result.gsub!("success", "successful")
    "SIC renewal successful. Gateway restart #{result}."
  rescue
    "SIC creation failed"
  end

  def swift_changes_pending(remote_version)
    SwiftChange.where(klass: %w(Partition PartitionSetting Gateway Proxy),
                      partition_id: self.partition_id).where("swift_version > ?", remote_version).count
  end

  def status_gateway(gateway_id)
    gateway = SwiftGateway.find_by_id(gateway_id)
    if gateway
      ret = Susshid::RemoteControl.status(gateway_id)
      version = ret['software_version']
      %w(return command master_pid software_version version susshid_id).each {|key| ret.delete(key) }
      ret.reverse_merge({id: self.id, name: self.name, susshid_identifier: self.susshid_identifier,
                         version: version, status: 'internal-error', system_time: nil }).stringify_keys
    end
  end

  private

  def before_validation_fill_susshid_identifier
    self.susshid_identifier = Gateway.next_identifier if self.susshid_identifier.blank?
  end

  def after_commit_update_sic_and_partition_settings
    self.update_columns(sic_psk: SecureRandom.hex) if self.sic_psk.blank?
    self.create_sic_certificate if self.sic_certificate.blank?
    self.create_syslog_certificate if self.syslog_certificate.blank?
    self.create_sic_ssh_key if self.sic_ssh_private_key.blank?
  end

  def validate_ip_addresses
    self.listen_addresses.reject!(&:blank?)
    self.listen_addresses.uniq!
    self.listen_addresses.compact!
    self.listen_addresses.each do |addr|
      port = 22
      addrc = addr.dup
      if addr =~ /([0-9]|\.)+:[0-9]+/
        # IPv4 addr:port form
        port = addr.split(':').last.to_i
        addrc.gsub!(/:[0-9]+/,'')
      else
        if addr =~ /\[.*:.*\]:[0-9]+/
          # IPv6 [addr]:port form
          port = addr.split(']:').last.to_i
          addrc.gsub!(/\]:[0-9]*/,'').gsub!(/[\[\]]/, '')
        end
      end
      if (IPAddress(addrc) rescue nil).blank?
        errors.add(:listen_addresses, "Address #{addr} is invalid")
      end
      unless port.between?(1, 65534)
        errors.add(:listen_addresses, "Port #{port} is out of range")
      end
    end
  end
end

