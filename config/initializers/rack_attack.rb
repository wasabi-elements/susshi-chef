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


#--- RACK Attack environment variables
RACK_ATTACK_REQUESTS_PER_MIN = ENV['API_REQUESTS_PER_MIN'].blank? ? 600 : ENV['API_REQUESTS_PER_MIN'].to_i

class Rack::Attack

  ### Configure Cache ###
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  Rack::Attack.safelist('allow from localhost') do |req|
    # Requests are allowed if the return value is truthy
    '127.0.0.1' == req.ip || '::1' == req.ip
  end

  ### Throttle all Config API requests by IP (30rpm) ###
  # Key: "rack::attack:#{Time.now.to_i/:period}:api/config/ip:#{req.ip}"

  throttle('api/config/ip', limit: RACK_ATTACK_REQUESTS_PER_MIN, period: 1.minute) do |req|
    if req.path =~ /\/api\/v[0-9.]+\/config.*/
      req.ip
    end
  end

  ### Throttle all Operations API requests by IP (30rpm) ###
  # Key: "rack::attack:#{Time.now.to_i/:period}:api/operations/ip:#{req.ip}"
  throttle('api/operations/ip', limit: (RACK_ATTACK_REQUESTS_PER_MIN/30), period: 1.minutes) do |req|
    if req.path =~ /\/api\/v[0-9.]+\/operations\/.*/
      req.ip
    end
  end

  ### Prevent Brute-Force Login Attacks ###

  ### Throttle POST requests to /login by IP address ###
  # Key: "rack::attack:#{Time.now.to_i/:period}:logins/ip:#{req.ip}"
  throttle('logins/ip', limit: 5, period: 3.minutes) do |req|
    if req.path == '/login' && req.post?
      req.ip
    end
  end

  ### Custom Throttle Response ###

  # By default, Rack::Attack returns an HTTP 429 for throttled responses,
  # which is just fine.
  #
  # If you want to return 503 so that the attacker might be fooled into
  # believing that they've successfully broken your app (or you just want to
  # customize the response), then uncomment these lines.
  # self.throttled_response = lambda do |env|
  #  [ 503,  # status
  #    {},   # headers
  #    ['']] # body
  # end
end