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

class NGINX
  NGINX_BINARY = "/usr/sbin/nginx"

  class << self

    def export_certificates
      pref = Preference.first

      ssl_dir = "#{Rails.root}/config/ssl"
      Dir.mkdir ssl_dir rescue nil

      # API SSL
      File.open("#{ssl_dir}/ca.pem", 'w') { |file| file.write(pref.sic_ca_certificate&.data) }
      File.open("#{ssl_dir}/api.crt", 'w') { |file| file.write(pref.sic_api_certificate&.data) }
      File.open("#{ssl_dir}/api.key", 'w') { |file| file.write(pref.sic_api_key&.data) }

      # UI SSL
      if pref.active_server_certificate
        crt = pref.active_server_certificate.data
        key = pref.active_server_key.data
      else
        crt = pref.alt_server_certificate.data
        key = pref.alt_server_key.data
      end

      File.open("#{ssl_dir}/server.crt", 'w') { |file| file.write(crt) }
      File.open("#{ssl_dir}/server.key", 'w') { |file| file.write(key) }

      true
    end

    def export_ssl_cc_config
      pref = Preference.first

      ssl_dir = "#{Rails.root}/config/ssl"
      nginx_dir = "#{Rails.root}/config/nginx/conf.d"

      if pref.ui_ssl_client_cert_verify == true
        Dir.mkdir ssl_dir rescue nil
        File.open("#{ssl_dir}/ca-cc.pem", 'w') { |file| file.write(pref.ui_ssl_client_cert_ca) }

        File.open("#{nginx_dir}/ui-ssl-cc-1.conf", 'w') do |file|
          file.puts <<~EOF
            ssl_client_certificate ssl/ca-cc.pem;
            ssl_verify_client optional;
            ssl_verify_depth #{pref.ui_ssl_client_cert_verify_depth};
          EOF
        end

        File.open("#{nginx_dir}/ui-ssl-cc-2.conf", 'w') do |file|
          file.puts <<~EOF
            if ($ssl_client_verify != SUCCESS) {
               return 403;
               break;
            }
            if ($ssl_client_s_dn_cn !~ "#{pref.ui_ssl_client_cert_cn_pattern}") {
               return 403;
               break;
            }
          EOF
        end
      else
        File.write("#{ssl_dir}/ca-cc.pem","")
        File.write("#{nginx_dir}/ui-ssl-cc-1.conf", "")
        File.write("#{nginx_dir}/ui-ssl-cc-2.conf", "")
      end
    end

    def reload
      if File.exist?(NGINX_BINARY)
        system(NGINX_BINARY, '-s', 'reload')
      end
    end

  end

end
