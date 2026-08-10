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

class SshKey < ApplicationRecord

  self.abstract_class = true

  #-- Datatypes

  #-- Associations

  #-- Scopes

  #-- Validations

  validate :validate_pubkey

  #-- Callbacks

  before_validation :before_validation_update_fields

  #-- Exception handling
  class PublicKeyError < StandardError
  end

  #-- Class Methods

  class << self

    def ssh_key_types
      {
          'ssh-rsa' => 'rsa',
          'ssh-ed25519' => 'ed25519',
          'ecdsa-sha2-nistp256' => 'ecdsa',
          'ecdsa-sha2-nistp384' => 'ecdsa',
          'ecdsa-sha2-nistp521' => 'ecdsa'
      }
    end

    def ssh_key_type_collection
      [['RSA', 'ssh-rsa'],
       ['ED 25519', 'ssh-ed25519'],
       ['ECDSA sha2-nistp-256', 'ecdsa-sha2-nistp256'],
       ['ECDSA sha2-nistp-384', 'ecdsa-sha2-nistp384'],
       ['ECDSA sha2-nistp-521', 'ecdsa-sha2-nistp521']]
    end

    def ssh_key_type_with_len_collection
      [['RSA (1024 to 2047 bits)', 'ssh-rsa:1024'],
       ['RSA (2048 to 3071 bits)', 'ssh-rsa:2048'],
       ['RSA (3072 to 4095 bits)', 'ssh-rsa:3072'],
       ['RSA (4096 and higher bits)', 'ssh-rsa:4096'],
       ['ED 25519 (256 bits)', 'ssh-ed25519:256'],
       ['ECDSA sha2-nistp-256 (256 bits)', 'ecdsa-sha2-nistp256:256'],
       ['ECDSA sha2-nistp-384 (384 bits)', 'ecdsa-sha2-nistp384:384'],
       ['ECDSA sha2-nistp-521 (521 bits)', 'ecdsa-sha2-nistp521:521']]
    end

    def generate_key_data(key_type, bits, comment)
      private_blob = public_blob = fingerprint = nil

      Dir.mktmpdir do |dir|
        key_file = File.join(dir, "key")
        pub_file = File.join(dir, "key.pub")

        cmd = [SSH_KEYGEN, "-t", key_type, "-b", bits.to_s, "-f", key_file, "-C", comment, "-N", ""]
        _, status = Open3.capture2(*cmd)

        if status.success?
          fingerprint = sha256_fingerprint(File.read(pub_file))
          unless fingerprint.nil?
            private_blob = File.read(key_file)
            public_blob = File.read(pub_file)
          end
        end
      end

      [public_blob, private_blob, fingerprint]
    end

    def pubkey_without_comment(public_key)
      raise PublicKeyError, 'newlines are not permitted between key data' if public_key =~ /\n(?!$)/

      parsed = public_key.split(/\s+/)
      parsed.each_with_index do |el, index|
        return parsed[index..(index+1)].join(' ') if ssh_key_types[el]
      end
      raise PublicKeyError, 'cannot determine key type'
    end

    def pubkey_blob_only(public_key)
      raise PublicKeyError, 'newlines are not permitted between key data' if public_key =~ /\n(?!$)/

      parsed = public_key.split(/\s+/)
      parsed.each_with_index do |el, index|
        return parsed[index+1] if ssh_key_types[el]
      end
      raise PublicKeyError, 'cannot determine key type'
    end

    def valid_ssh_public_key?(public_key)
      begin
        key = Net::SSH::KeyFactory.load_data_public_key(public_key)
        if key
          return true
        else
          false
        end
      rescue Exception
        false
      end
    end

    def sha256_fingerprint(public_key)
      key = Net::SSH::KeyFactory.load_data_public_key(public_key)
      "SHA256:#{Base64.encode64(Digest::SHA256.digest(key.to_blob)).gsub(/[\n=]/, '')}"
    end

    def ssh_public_key_bits(public_key)
      key = Net::SSH::KeyFactory.load_data_public_key(public_key)

      kt = key.ssh_type
      if kt.blank?
        pkt = self.public_blob.split(/\s+/).first
        kt = pkt if SshKey.ssh_key_types.keys.include?(pkt)
      end

      case kt
        when 'ssh-ed25519'
          256
        when 'ecdsa-sha2-nistp256', 'ecdsa-sha2-nistp384', 'ecdsa-sha2-nistp521'
          return kt.gsub('ecdsa-sha2-nistp','').to_i
        when 'ssh-rsa'
          key.n.num_bytes * 8
      end
    end

    def ssh_key_type(public_key)
      key = Net::SSH::KeyFactory.load_data_public_key(public_key)
      kt = key.ssh_type
      if kt.blank?
        pkt = self.public_blob.split(/\s+/).first
        kt = pkt if SshKey.ssh_key_types.keys.include?(pkt)
      end
      kt
    rescue
      nil
    end

  end

  #-- Instance Methods

  def valid_ssh_public_key?
    SSHKey.valid_ssh_public_key?(self.public_blob) &&
      SshKey.valid_ssh_public_key?(self.public_blob)
  end

  def ssh_key_type
    SshKey.ssh_key_type(self.public_blob)
  end

  def sha256_fingerprint
    SshKey.sha256_fingerprint(self.public_blob)
  end

  def ssh_public_key_bits
    SshKey.ssh_public_key_bits(self.public_blob)
  end


  private

  def validate_pubkey
    unless self.valid_ssh_public_key?
      errors.add(:public_blob, 'Key is not in a known format or of a known type')
    end
  end

  def before_validation_update_fields
    return if self.public_blob.blank?
    pubkey = self.public_blob

    unless SshKey.valid_ssh_public_key?(pubkey)
      # Try to convert it with ssh-keygen
      input = Tempfile.new('susshi-chef')
      input.write(self.public_blob)
      input.close
      %w(PKCS8 RFC4716).each do |format|
        cmd = [SSH_KEYGEN, "-i", "-m", format, "-f", input.path]
        stdout, status = Open3.capture2(*cmd)

        if status.success?
          pubkey = stdout.split(/\s+/)[(0..1)].join(' ') rescue nil
          break unless pubkey.blank?
        end
      end
      input.unlink
    end
    if SshKey.valid_ssh_public_key?(pubkey)
      begin
        self.public_blob = SshKey.pubkey_without_comment(pubkey)
        self.fingerprint = sha256_fingerprint
        self.bits = ssh_public_key_bits
        self.key_type = ssh_key_type
      rescue
        return
      end
    end
  end

end