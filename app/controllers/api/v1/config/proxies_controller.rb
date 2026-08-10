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

module Api::V1::Config
  class ProxiesController < ApiController

    wrap_parameters :proxy, include: [:name, :realm, :hostname, :port, :contact, :description, :comment, :use_individual_identities]

    private

    def ee_write_feature? = Subscription.instance.feature_proxies?

    def strong_params
      params.require(:proxy).permit(:name, :realm, :hostname, :port, :contact, :description, :comment, :use_individual_identities)
    end

    def rack_reducers
      super + [
          ->(comment:) { where(api_query_search_string(:comment, comment)) },
          ->(contact:) { where(api_query_search_string(:contact, contact)) },
          ->(description:) { where(api_query_search_string(:description, description)) },
          ->(hostname:) { where(api_query_search_string(:hostname, hostname)) },
          ->(port:) { where(port: port) },
          ->(realm:) { where(api_query_search_string(:realm, realm)) },
          ->(use_individual_identities:) { where(use_individual_identities: use_individual_identities) }
      ]
    end

  end
end