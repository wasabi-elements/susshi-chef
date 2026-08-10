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

class Rsyslog::Config
  SSL_DIR = Rails.root.join("config", "ssl").freeze

  class << self

    def path_conf_dir
      Rails.root.join("config", "rsyslog")
    end

    def path_conf_file
      path_conf_dir.join("rsyslogd.conf")
    end

    def write
      FileUtils.mkdir_p(path_conf_dir)
      path_conf_file.write(render)
    end

    private

    def render
      ERB.new(template, trim_mode: "-").result(binding)
    end

    def template
      File.read(Rails.root.join("app", "services", "rsyslog", "templates", "rsyslogd.conf.erb"))
    end

    def db_config
      @db_config ||= ActiveRecord::Base.connection_db_config.configuration_hash
    end

    def preference
      Preference.instance
    end

    def gateways
      @gateways = SwiftGateway.order(:identifier).pluck(:identifier).map { |i| "syslog-#{i}" }
    end

    def targets
      @targets = [
        preference.syslog_server1,
        preference.syslog_server2,
        preference.syslog_server3,
        preference.syslog_server4
      ].reject(&:blank?)
    end

    def target_port
      preference.syslog_port.blank? ? 514 : preference.syslog_port.to_i
    end

    def target_module
      preference.syslog_proto == "relp" ? "omrelp" : "omfwd"
    end

    def tls_permitted_peers
      peers = gateways.map { |gw| %("#{gw}") }.join(", ")
      peers.blank? ? '"no_gateways_so_far"' : peers
    end

  end
end
