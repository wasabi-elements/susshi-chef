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

module RequestDebug
  def debug_request
    # --- basics
    Rails.logger.debug "=== REQUEST DEBUG ==="
    Rails.logger.debug "UUID:    #{request.uuid}"
    Rails.logger.debug "Method:  #{request.request_method}"
    Rails.logger.debug "Path:    #{request.fullpath}"
    Rails.logger.debug "IP:      #{request.remote_ip}"
    Rails.logger.debug "Format:  #{request.format}"

    # --- headers (only HTTP_* plus a few useful ones)
    headers = request.headers.env
                     .select { |k, _| k.start_with?('HTTP_') || %w[CONTENT_TYPE CONTENT_LENGTH].include?(k) }
    Rails.logger.debug "Headers: #{headers}"

    # --- params (unfiltered hash)
    # NOTE: params.inspect filters sensitive keys; to see raw keys, use to_unsafe_h.
    Rails.logger.debug "Params:  #{params.to_unsafe_h}"

    # --- raw body (if you need what Rack received, e.g., JSON before parsing)
    raw = request.body.read
    request.body.rewind # important: so other code can read it again
    Rails.logger.debug "Raw body (#{raw.bytesize} bytes): #{raw}"

    # --- rails' parsed pieces
    Rails.logger.debug "Query params:   #{request.query_parameters}"
    Rails.logger.debug "Request params: #{request.request_parameters}" # POSTed form/JSON
    Rails.logger.debug "Path params:    #{request.path_parameters}"
  end
end