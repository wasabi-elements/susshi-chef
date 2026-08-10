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

# Learn more: http://github.com/javan/whenever

require File.expand_path(File.dirname(__FILE__) + '/environment')

env "CHEF_MASTER_KEY", ENV["CHEF_MASTER_KEY"]
env "RAILS_ENV", Rails.env
env "RAILS_ROOT", Rails.root
env "RBENV_ROOT", ENV["RBENV_ROOT"]
env "SIC_CERTS_EXPIRY_DAYS", ENV["SIC_CERTS_EXPIRY_DAYS"]
env "SIC_CERTS_LIFETIME_DAYS", ENV["SIC_CERTS_LIFETIME_DAYS"]

job_type :rake, "cd $RAILS_ROOT; /usr/local/rbenv/shims/bundle exec rails :task >> $RAILS_ROOT/log/$RAILS_ENV-rake.log"

every "10 3 * * *" do
  rake "chef:purge_logs_and_reports"
end

every "20 3 * * *" do
  rake "chef:garbage_ip_caching"
end

every "30 3 * * *" do
  rake "chef:renew_sic_certificates"
end

every "40 3 * * *" do
  rake "db:sessions:trim"
end
