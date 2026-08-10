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

class Rsyslog::Daemon
  class << self

    def restart
      return unless runnable?

      # Serialize concurrent restarts (e.g. from multiple Puma workers)
      ActiveRecord::Base.with_advisory_lock("rsyslog_daemon_restart") do
        Rsyslog::Config.write

        stop_daemon
        start_daemon
      end
    end

    alias_method :startup, :restart

    def restart_required?(partition, swift_version = nil)
      swift_version ||= partition.current_swift_version
      klasses = %w[Gateway Partition PartitionSetting]

      partition.swift_changes.exists?(klass: klasses, swift_version:)
    end

    private

    def runnable?
      binary_exists? && tls_files_exist?
    end

    def binary_exists?
      defined?(RSYSLOG_DAEMON) && File.exist?(RSYSLOG_DAEMON)
    end

    def tls_files_exist?
      %w[api.crt api.key ca.pem].all? { |f| File.exist?(File.join(Rsyslog::Config::SSL_DIR, f)) }
    end

    def stop_daemon
      return unless File.exist?(RSYSLOG_PID)

      pid = File.read(RSYSLOG_PID).to_i
      begin
        Process.kill("TERM", pid)
      rescue Errno::ESRCH
        File.delete(RSYSLOG_PID)
      end

      10.times do
        break unless File.exist?(RSYSLOG_PID)
        sleep 1
      end
    end

    def start_daemon
      Open3.capture2(RSYSLOG_DAEMON, "-f", Rsyslog::Config.path_conf_file.to_s, "-i", RSYSLOG_PID)
    rescue => e
      Rails.logger.error("(Re)start of rsyslogd failed: #{e.message}")
    end

  end
end
