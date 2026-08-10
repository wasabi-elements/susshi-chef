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
  module Misc
    # Split host and port number from string.
    def parse_socket_addr(string)
      case string
      when /\A\[([^\]]+)\]:([0-9]+)\z/      # string like "[::1]:80"
        address, port = $1, $2
      when /\A([^:]+):([0-9]+)\z/           # string like "127.0.0.1:80"
        address, port = $1, $2
      else                                  # string with no port number
        address, port = string, nil
      end

      port = port.to_i
      port = nil unless (1..65535).include?(port)
      [ address, port ]
    end
  end
end
