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

class SystemEventLogger < Logger

  @@logger = nil

  #-- Class Methods

  class << self
    def logger
      @@logger ||= SystemEventLogger.new(File::NULL)
    end
  end

  #-- Instance Methods

  def add severity, message = nil, progname = nil, susshid_identifier: nil
    severity ||= UNKNOWN

    return true if severity < level

    if message.nil?
      if block_given?
        message = yield
      else
        message  = progname
      end
    end

    fromhost =
      if susshid_identifier
        gateway = Gateway.find_by(susshid_identifier:)
        "#{gateway.susshid_identifier}-#{gateway.name}"
      else
          "0000-suSSHi Chef"
      end

    SystemEvent.create(
        fromhost:,
        receivedat: Time.now,
        devicereportedtime: Time.now,
        message:,
        facility: 4,
        priority: severity_to_priority(severity)
    )
    true
  end
  alias log add

  private

  def severity_to_priority(severity)
    # rsyslog priorities: Emergency=0 Alert Critical Error Warning Notice Info Debug=7
    {
      Logger::FATAL => 0,
      Logger::ERROR => 3,
      Logger::WARN => 4,
      Logger::INFO => 6,
      Logger::DEBUG => 7,
    }[severity] || 7
  end

end