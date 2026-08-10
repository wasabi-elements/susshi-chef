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

module Api
  module V1
    module Validate
      class Reports

        include ActiveModel::Validations

        attr_accessor :susshid_id, :partition_id, :reports

        validates :susshid_id, presence: true, length: { is: 4 }
        validates :reports, presence: true

        def initialize(call_params={})
          # Here we are receiving Body Params and no JSON, so the parameters are not wrapped into "report:"
          params = call_params.permit(:format, :InstallationId, :SusshidId, :Reports)
          @susshid_id      = params[:SusshidId]
          @reports         = params[:Reports]
        end

      end
    end
  end
end
