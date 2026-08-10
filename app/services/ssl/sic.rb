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

class SSL::Sic
  class << self
    def create_sic_ca
      preference = Preference.first

      key_pair = OpenSSL::PKey::RSA.new(4096)

      cn = "susshi-chef"
      subject = "/C=DE/O=Wasabi Elements GmbH/OU=SIC/OU=Susshi Key Signing/CN=#{cn}"

      cert = OpenSSL::X509::Certificate.new
      cert.subject = cert.issuer = OpenSSL::X509::Name.parse(subject)
      cert.not_before = Time.now
      cert.not_after = Time.now + 10.years
      cert.public_key = key_pair.public_key
      cert.serial = preference.certificate_index
      cert.version = 3

      ef = OpenSSL::X509::ExtensionFactory.new
      ef.subject_certificate = cert
      ef.issuer_certificate = cert
      cert.extensions = [
        ef.create_extension('basicConstraints', 'CA:TRUE', true),
        ef.create_extension('subjectKeyIdentifier', 'hash'),
        ef.create_extension('keyUsage', %w(cRLSign keyCertSign).join(','), true)
      ]
      cert.add_extension ef.create_extension('authorityKeyIdentifier', 'keyid:always,issuer:always')

      cert.sign key_pair, OpenSSL::Digest::SHA512.new

      preference.sic_ca_certificate ||= preference.build_sic_ca_certificate
      preference.sic_ca_certificate.update!(data: cert.to_pem)

      preference.sic_ca_key ||= preference.build_sic_ca_key
      preference.sic_ca_key.update!(data: key_pair.to_s)

      preference.update_columns(certificate_index: preference.certificate_index + 1)
    end


    def create_sic_api_certificate
      preference = Preference.first

      return if preference.sic_ca_key.blank?
      return if preference.sic_ca_certificate.blank?

      key, cert = create_certificate(
        "susshi-chef-api",
        Time.now + 10.years
      )

      if [key, cert].none?(&:blank?)
        preference.sic_api_key ||= preference.build_sic_api_key
        preference.sic_api_key.update!(data: key)

        preference.sic_api_certificate ||= preference.build_sic_api_certificate
        preference.sic_api_certificate.update!(data: cert)

        preference.update_columns(certificate_index: preference.certificate_index + 1)
      end
    end

    def create_sic_certificate(gateway)
      preference = Preference.first

      return if preference.sic_ca_key.blank?
      return if preference.sic_ca_certificate.blank?

      key, cert = create_certificate(
        "susshid-#{gateway.susshid_identifier}",
        Time.now + ENV['SIC_CERTS_LIFETIME_DAYS'].to_i.days
      )

      if [key, cert].none?(&:blank?)
        gateway.sic_key ||= gateway.build_sic_key
        gateway.sic_key.update!(data: key)

        gateway.sic_certificate ||= gateway.build_sic_certificate
        gateway.sic_certificate.update!(data: cert)

        preference.update_columns(certificate_index: preference.certificate_index + 1)
      end
    end

    def create_sic_certificate_p12(gateway, password)
      return unless gateway&.is_a? SwiftGateway
      return if password.nil?

      preference = Preference.first
      OpenSSL::PKCS12.create(
        password,
        gateway.identifier,
        OpenSSL::PKey::RSA.new(gateway.sic_key),
        OpenSSL::X509::Certificate.new(gateway.sic_certificate),
        [OpenSSL::X509::Certificate.new(preference.sic_ca_certificate.data)]
      )
    end

    def create_syslog_certificate(gateway)
      preference = Preference.first

      return if preference.sic_ca_key.blank?
      return if preference.sic_ca_certificate.blank?

      key, cert = create_certificate(
        "syslog-#{gateway.susshid_identifier}",
        Time.now + ENV['SIC_CERTS_LIFETIME_DAYS'].to_i.days
      )

      if [key, cert].none?(&:blank?)
        gateway.syslog_key ||= gateway.build_syslog_key
        gateway.syslog_key.update!(data: key)

        gateway.syslog_certificate ||= gateway.build_syslog_certificate
        gateway.syslog_certificate.update!(data: cert)

        preference.update_columns(certificate_index: preference.certificate_index + 1)
      end
    end

    private

    def create_certificate(common_name, not_after)
      preference = Preference.first

      key_pair = OpenSSL::PKey::RSA.new(4096)

      ca_key = OpenSSL::PKey::RSA.new(preference.sic_ca_key.data)
      ca     = OpenSSL::X509::Certificate.new(preference.sic_ca_certificate.data)

      subject = "/C=DE/O=Wasabi Elements GmbH/OU=SIC/OU=Susshi Key/CN=#{common_name}"

      cert            = OpenSSL::X509::Certificate.new
      cert.subject    = cert.issuer = OpenSSL::X509::Name.parse(subject)
      cert.not_before = Time.now
      cert.not_after  = not_after
      cert.public_key = key_pair.public_key
      cert.serial     = preference.certificate_index
      cert.version    = 3

      ef                     = OpenSSL::X509::ExtensionFactory.new
      ef.subject_certificate = cert
      ef.issuer_certificate  = ca
      cert.issuer            = ca.subject
      cert.extensions        = [
        ef.create_extension('basicConstraints', 'CA:FALSE', true),
        ef.create_extension('subjectKeyIdentifier', 'hash'),
        ef.create_extension('keyUsage', %w(digitalSignature keyEncipherment dataEncipherment).join(','), true),
        ef.create_extension('subjectAltName', "DNS:#{common_name}")
      ]
      cert.add_extension ef.create_extension('authorityKeyIdentifier', 'keyid:always,issuer:always')

      cert.sign ca_key, OpenSSL::Digest::SHA512.new

      [key_pair.to_s, cert.to_pem]
    end
  end
end
