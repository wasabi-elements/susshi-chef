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

class Susshid::Memcrypt

  require 'openssl'
  require 'base64'

  class << self

    def encrypt_aes256_gcm(plain_text, key)
      cipher = OpenSSL::Cipher.new("AES-256-GCM")
      cipher.encrypt

      # 12 byte random IV
      iv  = cipher.random_iv

      cipher.key = key
      encrypted  = cipher.update(plain_text) + cipher.final

      # 16 byte authentication tag
      tag = cipher.auth_tag

      Base64.strict_encode64(iv + tag + encrypted)
    end

  end
end
