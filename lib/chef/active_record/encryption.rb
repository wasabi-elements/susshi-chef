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
  module ActiveRecord
    module Encryption
      class << self
        MASTER_KEY_FALLBACK = "957aeb5b995f42b15d0ca0b73df8dda9cf486de07c2197d2cc83ef9a02d2de79"
        MASTER_KEY_MIN_LENGTH = 32

        def setup
          if Rails.env.development?
            if ENV["CHEF_MASTER_KEY"].blank?
              puts message_not_found_development

              ENV["CHEF_MASTER_KEY"] = MASTER_KEY_FALLBACK
            end
          end

          if ENV["CHEF_MASTER_KEY"].blank?
            puts message_not_found

            exit 127
          else
            if ENV["CHEF_MASTER_KEY"].size < MASTER_KEY_MIN_LENGTH
              puts message_min_length

              exit 127
            end

            key_derivation_salt = Digest::MD5.hexdigest(
              deterministic_key = Digest::MD5.hexdigest(
                primary_key = Digest::MD5.hexdigest(
                  ENV["CHEF_MASTER_KEY"]
                )
              )
            )

            Rails.application.configure do
              # https://guides.rubyonrails.org/active_record_encryption.html#setup
              config.active_record.encryption.primary_key = primary_key
              config.active_record.encryption.deterministic_key = deterministic_key
              config.active_record.encryption.key_derivation_salt = key_derivation_salt
            end
          end
        end

        private

        def message_min_length
          <<~EOM
            => Environment variable 'CHEF_MASTER_KEY' has to be at least #{MASTER_KEY_MIN_LENGTH} characters
            =>   * For example, please use `openssl rand -hex 32` to generate a key
          EOM
        end

        def message_not_found
          <<~EOM
            => Environment variable 'CHEF_MASTER_KEY' not found
            =>   * For example, please use `openssl rand -hex 32` to generate a key
          EOM
        end

        def message_not_found_development
          <<~EOM
            => Environment variable 'CHEF_MASTER_KEY' not found
            =>   * Using default value '#{MASTER_KEY_FALLBACK}'
          EOM
        end
      end # class << self
    end # module Encryption
  end # module ActiveRecord
end # module Chef
