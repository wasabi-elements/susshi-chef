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

#-- Other Initializers
require "chef/misc"
require "chef/susshid_settings"
require "chef/swift_tracker"
require "chef/jsonb_coder"

require "jwt"

#-- Controller-Validators
require Rails.root.join("app", "controllers", "api", "v1", "validate", "gateways")
require Rails.root.join("app", "controllers", "api", "v1", "validate", "reports")
require Rails.root.join("app", "controllers", "api", "v1", "validate", "sessions")

#-- Define location of ssh-keygen
if File.executable?("/usr/bin/ssh-keygen")
  SSH_KEYGEN = "/usr/bin/ssh-keygen"
else
  raise "ssh-keygen not found or executable"
end

#-- Define location of rsyslogd
if File.executable?("/usr/sbin/rsyslogd")
  RSYSLOG_DAEMON = "/usr/sbin/rsyslogd"
  RSYSLOG_PID = File.join(Rails.root, "tmp", "rsyslogd.pid")
end

#-- GIT Version
GIT_INFO = (File.read(File.join(Rails.root, "config", ".git_info")).strip) rescue "develop"

#-- SIC Expiration
SIC_CERTS_LIFETIME_DAYS_DEFAULT = 47
SIC_CERTS_EXPIRY_DAYS_DEFAULT = 30

if %w[development production].include?(Rails.env)
  if ENV["SIC_CERTS_LIFETIME_DAYS"].blank?
    puts <<~EOM
      => Environment variable 'SIC_CERTS_LIFETIME_DAYS' not found in environment
      =>   * Using default value of #{SIC_CERTS_LIFETIME_DAYS_DEFAULT} (days)
    EOM

    ENV["SIC_CERTS_LIFETIME_DAYS"] = SIC_CERTS_LIFETIME_DAYS_DEFAULT.to_s
  end

  if ENV["SIC_CERTS_LIFETIME_DAYS"].to_i < SIC_CERTS_LIFETIME_DAYS_DEFAULT
    puts <<~EOM
      => Environment variable 'SIC_CERTS_LIFETIME_DAYS' set to low (#{ENV["SIC_CERTS_LIFETIME_DAYS"]})
      =>   * Using default of #{SIC_CERTS_LIFETIME_DAYS_DEFAULT} (days)
    EOM

    ENV["SIC_CERTS_LIFETIME_DAYS"] = SIC_CERTS_LIFETIME_DAYS_DEFAULT.to_s
  end

  if ENV["SIC_CERTS_EXPIRY_DAYS"].blank?
    puts <<~EOM
      => Environment variable 'SIC_CERTS_EXPIRY_DAYS' not found in environment
      =>   * Using default value of #{SIC_CERTS_EXPIRY_DAYS_DEFAULT} (days)
    EOM

    ENV["SIC_CERTS_EXPIRY_DAYS"] = SIC_CERTS_EXPIRY_DAYS_DEFAULT.to_s
  end

  if ENV["SIC_CERTS_EXPIRY_DAYS"].to_i < SIC_CERTS_EXPIRY_DAYS_DEFAULT
    puts <<~EOM
      => Environment variable 'SIC_CERTS_EXPIRY_DAYS' set to low (#{ENV["SIC_CERTS_EXPIRY_DAYS"]})
      =>   * Using default of #{SIC_CERTS_EXPIRY_DAYS_DEFAULT} (days)
    EOM

    ENV["SIC_CERTS_EXPIRY_DAYS"] = SIC_CERTS_EXPIRY_DAYS_DEFAULT.to_s
  end

  if ENV["SIC_CERTS_EXPIRY_DAYS"].to_i >= ENV["SIC_CERTS_LIFETIME_DAYS"].to_i - 7
    sic_cert_expiry_days = ENV["SIC_CERTS_LIFETIME_DAYS"].to_i - 7

    puts <<~EOM
      => Environment variable 'SIC_CERTS_EXPIRY_DAYS' (#{ENV["SIC_CERTS_EXPIRY_DAYS"]}) set to close to 'SIC_CERTS_LIFETIME_DAYS' (#{ENV["SIC_CERTS_LIFETIME_DAYS"]})
      =>   * Modifying 'SIC_CERTS_EXPIRY_DAYS' to #{sic_cert_expiry_days} (days)
    EOM

    ENV["SIC_CERTS_EXPIRY_DAYS"] = sic_cert_expiry_days.to_s
  end

  if defined?(EE::Engine)
    puts <<~EOM

      Welcome to suSSHi Chef EE [Enterprise Edition]
      ----------------------------------------------
      Thank you for your support!

    EOM
  else
    puts <<~EOM

      Welcome to suSSHi Chef
      ----------------------

    EOM
  end
end
