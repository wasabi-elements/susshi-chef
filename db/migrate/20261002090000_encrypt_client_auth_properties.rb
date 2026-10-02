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

class EncryptClientAuthProperties < ActiveRecord::Migration[8.1]
  # Client auth properties can hold secrets

  class ClientAuth < ActiveRecord::Base
    self.table_name = 'client_auths'
    self.inheritance_column = nil
    encrypts :properties, support_unencrypted_data: true
  end

  class SwiftClientAuthSet < ActiveRecord::Base
    self.table_name = 'swift_client_auth_sets'
    encrypts :interactive_auth_properties, support_unencrypted_data: true
  end

  def up
    ClientAuth.find_each(&:encrypt)
    SwiftClientAuthSet.find_each(&:encrypt)
  end

  def down
    ClientAuth.find_each(&:decrypt)
    SwiftClientAuthSet.find_each(&:decrypt)
  end
end
