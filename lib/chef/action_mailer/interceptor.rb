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

module Chef
  module ActionMailer
    class Interceptor
      class << self

        def delivering_email(message)
          message.delivery_method.settings.merge!(chef_smtp_settings)
        end

        private

        def chef_smtp_settings
          config = {}

          return config if Preference.none?

          preference = Preference.first
          return config if preference.smtp_address.nil?

          attributes = %i[address port domain user_name authentication openssl_verify_mode]
          config = attributes.each_with_object({}) { |key, hash| hash[key] = preference.try("smtp_#{key}") }

          unless preference.smtp_password.blank?
            config[:password] = preference.smtp_password
          end

          case preference.smtp_encryption
          when /ssl\/tls/i
            config[:tls] = true
          when /starttls/i
            config[:enable_starttls] = true
          when /none/i
            config[:enable_starttls] = false
            config[:enable_starttls_auto] = false
            config[:tls] = false
          else
            # ActionMailer default
          end

          config.compact_blank
        end
      end # def chef_smtp_settings

    end # class Interceptor
  end # module ActiveMailer
end # module Chef
