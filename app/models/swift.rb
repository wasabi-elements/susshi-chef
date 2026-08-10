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

class Swift < ApplicationRecord

  self.abstract_class = true

  belongs_to :partition

  class << self

    # This method is used by SwiftPartition and SwiftProxy
    def ssh_keygen(priv_key, memcrypt_key)
      Dir.mktmpdir do |dir|
        key_file = File.join(dir, "key")

        File.write(key_file, priv_key)
        File.chmod(0600, key_file)

        cmd       = [SSH_KEYGEN, "-p", "-f", key_file, "-N", memcrypt_key, "-P", ""]
        _output, _status = Open3.capture2(*cmd)

        File.read(key_file).chomp
      end
    end

  end

end
