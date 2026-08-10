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

class SSL::Server

  class << self

    def create_alt_server_key_cert
      preference = Preference.first

      return unless preference.alt_server_key.blank?
      return unless preference.alt_server_certificate.blank?

      key_pair = OpenSSL::PKey::RSA.new(2048)
      public_key = key_pair.public_key
      cn = "susshi-chef"

      subject = "/C=DE/O=Wasabi Elements GmbH/OU=Susshi Server Key/CN=#{cn}"

      cert = OpenSSL::X509::Certificate.new
      cert.subject = cert.issuer = OpenSSL::X509::Name.parse(subject)
      cert.issuer  = cert.subject
      cert.not_before = Time.now
      cert.not_after = Time.now + 10 * 366 * 24 * 60 * 60
      cert.public_key = public_key
      cert.serial = Time.now.to_i
      cert.version = 2

      ef = OpenSSL::X509::ExtensionFactory.new
      ef.subject_certificate = cert
      ef.issuer_certificate = cert

      cert.extensions = [
          ef.create_extension('basicConstraints', 'CA:TRUE', true),
          ef.create_extension('subjectKeyIdentifier', 'hash', false),
          ef.create_extension('keyUsage', %w(digitalSignature keyCertSign cRLSign).join(','), true)
      ]

      cert.add_extension ef.create_extension('authorityKeyIdentifier', 'keyid:always', false)

      cert.sign key_pair, OpenSSL::Digest::SHA256.new

      preference.alt_server_certificate ||= preference.build_alt_server_certificate
      preference.alt_server_certificate.update!(data: cert.to_pem)

      preference.alt_server_key ||= preference.build_alt_server_key
      preference.alt_server_key.update!(data: key_pair.to_s)
    end

    def create_csr(options)
      key_pair = OpenSSL::PKey::RSA.new(options['rsa_size'].to_i)
      request = OpenSSL::X509::Request.new
      request.version = 0
      sub = []
      sub << ['C', options['c'], OpenSSL::ASN1::PRINTABLESTRING] unless options['c'].blank?
      sub << ['ST', options['st'], OpenSSL::ASN1::PRINTABLESTRING] unless options['st'].blank?
      sub << ['L', options['l'], OpenSSL::ASN1::PRINTABLESTRING] unless options['l'].blank?
      sub << ['O', options['o'], OpenSSL::ASN1::UTF8STRING] unless options['o'].blank?
      sub << ['OU', options['ou'], OpenSSL::ASN1::UTF8STRING] unless options['ou'].blank?
      sub << ['CN', options['cn'], OpenSSL::ASN1::UTF8STRING] unless options['cn'].blank?

      request.subject = OpenSSL::X509::Name.new(sub)
      request.public_key = key_pair.public_key
      ef = OpenSSL::X509::ExtensionFactory.new
      extensions = [
        # ef.create_extension('basicConstraints', 'CA:FALSE', true),
        # ef.create_extension('keyUsage',
        #                     %w(digitalSignature keyEncipherment).join(','),
        #                     true),
          ef.create_extension('subjectAltName',"DNS:#{options['cn']}")
      ]

      attribute_values = OpenSSL::ASN1::Set [OpenSSL::ASN1::Sequence(extensions)]
      [
          OpenSSL::X509::Attribute.new('extReq', attribute_values),
          OpenSSL::X509::Attribute.new('msExtReq', attribute_values)
      ].each do |attribute|
        request.add_attribute attribute
      end

      case options['sha_size'].to_i
        when 256
          request.sign key_pair, OpenSSL::Digest::SHA256.new
        when 384
          request.sign key_pair, OpenSSL::Digest::SHA384.new
        when 512
          request.sign key_pair, OpenSSL::Digest::SHA512.new
      end

      replace_server_key(key_pair.to_s)
      replace_server_csr(request.to_pem)
    end


    def activate_certificate
      preference = Preference.first
      return false if preference.server_certificate.blank?

      # This will also overwrite an active server certificate and key if there are any
      replace_active_server_key(preference.server_key.data)
      replace_active_server_certificate(preference.server_certificate.data)

      true
    end

    def validate_uploaded_certificate(certificate, priv = nil, passphrase = '')
      begin
        # Given Cert from upload
        cert = OpenSSL::X509::Certificate.new certificate
        # Our Public Key from Private key
        priv ||= Preference.first.server_key.data
        if priv =~ /Proc-Type.*ENCRYPTED/
          key = OpenSSL::PKey::RSA.new(priv, passphrase)
        else
          key = OpenSSL::PKey::RSA.new(priv)
        end
        # Compare strings
        cert.public_key.to_pem == key.public_key.to_pem
      rescue
        false
      end
    end

    def is_valid_certificate?(certificate)
      begin
        OpenSSL::X509::Certificate.new certificate
        true
      rescue
        false
      end
    end

    def certificate_info(certificate)
      cert = OpenSSL::X509::Certificate.new certificate
      Hash[*(%w(subject issuer not_before not_after version serial signature_algorithm).collect {|key|
        [key, cert.try(key)]
      }).flatten]
    end

    def replace_server_csr(pem)
      preference = Preference.first

      preference.server_csr ||= preference.build_server_csr
      preference.server_csr.update!(data: pem)
    end

    def replace_server_certificate(pem)
      preference = Preference.first

      preference.server_certificate ||= preference.build_server_certificate
      preference.server_certificate.update!(data: pem)
    end

    def replace_server_key(pem)
      preference = Preference.first

      preference.server_key ||= preference.build_server_key
      preference.server_key.update!(data: pem)
    end

    def replace_active_server_certificate(pem)
      preference = Preference.first

      preference.active_server_certificate ||= preference.build_active_server_certificate
      preference.active_server_certificate.update!(data: pem)
    end

    def replace_active_server_key(pem)
      preference = Preference.first

      preference.active_server_key ||= preference.build_active_server_key
      preference.active_server_key.update!(data: pem)
    end

  end


end
