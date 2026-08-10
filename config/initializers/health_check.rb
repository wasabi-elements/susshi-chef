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

HealthCheck.setup do |config|

  # uri prefix (no leading slash)
  config.uri = 'susshi-health'

  # Text output upon success
  config.success = 'Status: OK'

  # Timeout in seconds used when checking smtp server
  # config.smtp_timeout = 30.0

  # http status code used when plain text error message is output
  # Set to 200 if you want your want to distinguish between partial (text does not include success) and
  # total failure of rails application (http status of 500 etc)

  config.http_status_for_error_text = 500

  # http status code used when an error object is output (json or xml)
  # Set to 200 if you want your want to distinguish between partial (healthy property == false) and
  # total failure of rails application (http status of 500 etc)

  config.http_status_for_error_object = 500

  # bucket names to test connectivity - required only if s3 check used, access permissions can be mixed
  # config.buckets = {'bucket_name' => [:R, :W, :D]}

  # You can customize which checks happen on a standard health check, eg to set an explicit list use:
  config.standard_checks = [ 'database', 'migrations', 'custom' ]

  # Or to exclude one check:
  # config.standard_checks -= [ 'emailconf' ]

  # You can set what tests are run with the 'full' or 'all' parameter
  # config.full_checks = ['database', 'migrations', 'custom', 'email', 'cache', 'redis', 'resque-redis', 'sidekiq-redis', 's3']
  config.full_checks = ['database', 'migrations', 'cache' ]

  # Add one or more custom checks that return a blank string if ok, or an error message if there is an error
  #config.add_custom_check do
  #  CustomHealthCheck.perform_check # any code that returns blank on success and non blank string upon failure
  #end

  # Add another custom check with a name, so you can call just specific custom checks. This can also be run using
  # the standard 'custom' check.
  # You can define multiple tests under the same name - they will be run one after the other.
  # config.add_custom_check('sometest') do
  #
  # end

  # max-age of response in seconds
  # cache-control is public when max_age > 1 and basic_auth_username is not set
  # You can force private without authentication for longer max_age by
  # setting basic_auth_username but not basic_auth_password
  config.max_age = 1

  # Protect health endpoints with basic auth
  # These default to nil and the endpoint is not protected
  # config.basic_auth_username = 'my_username'
  # config.basic_auth_password = 'my_password'

  # Whitelist requesting IPs
  # Defaults to blank and allows any IP
  config.origin_ip_whitelist = %w(127.0.0.1)

  # http status code used when the ip is not allowed for the request
  config.http_status_for_ip_whitelist_error = 403

  # When redis url is non-standard
  config.redis_url = 'redis_url'

  # Disable the error message to prevent /health_check from leaking
  # sensitive information
  # config.include_error_in_response_body = false
end