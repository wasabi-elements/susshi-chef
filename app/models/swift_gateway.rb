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

class SwiftGateway < Swift
  encrypts :sic_psk, :sic_certificate, :sic_key, :sic_ssh_private_key, :syslog_certificate, :syslog_key

  belongs_to :partition

  class << self
    def by_reachability(partition_id)
      queue = Queue.new(SwiftGateway.where(partition_id: partition_id))

      gateways = []

      threads = (queue.size < 10 ? queue.size : 10).times.map do
        Thread.new do
          while (gateway = (queue.pop(true) rescue nil))
            Socket.tcp(gateway.sic_host, gateway.sic_port || 22, connect_timeout: 3) { gateways << gateway } rescue false
          end
        end
      end

      threads.map(&:join)

      gateways
    end
  end

end
