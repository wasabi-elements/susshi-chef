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

class ApiApplicationController < ActionController::Base

  skip_forgery_protection

  ActionController::Parameters.action_on_unpermitted_parameters = :raise

  def validate_params(validator)
    unless validator.valid?
      respond_to do |format|
        format.text { render text: validator.errors.join('\n'), status: :bad_request }
        format.json { render json: { error: validator.errors }, status: :bad_request }
        format.xml { render  xml: { error: validator.errors }, status: :bad_request }
        format.p12 { head :bad_request }
        format.pem { head :bad_request }
      end
    end
  end

  rescue_from(ActionController::UnpermittedParameters) do |pme|
    render json: { error: { unknown_parameters: pme.params } },
           status: :bad_request
  end

  def gateway_version
    request.user_agent.split(/[_ ]/).second rescue '00.00'
  end

  def gateway_version_uint32
    (gateway_version.split('.').map{|x| "%02d" % x.to_i }.join('').to_i) rescue 0
  end

end
