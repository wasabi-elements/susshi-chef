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
      module Operations
        class Oidc

          include ActiveModel::Validations

          attr_accessor :secret, :jwt, :jwt_aud, :jwt_iss, :jwt_sid, :jwt_sub

          validates :jwt_aud, presence: true

          validates :jwt_iss, presence: true
          validates :jwt_iss, format: { with: /\Ahttps:\/\/.+\z/, message: "must be an URL that starts with https://" }
          validates :jwt_sid, length: { maximum: 255 }, allow_nil: true
          validates :jwt_sub, length: { maximum: 255 }, allow_nil: true
          validates :secret, length: { :is => 32 }, allow_blank: true

          # TODO: Validate param "uid", which is missing for logout

          def initialize(call_params = {})
            params   = call_params.require(:oidc).permit(:secret, jwt: {})
            @secret  = params[:secret]
            @jwt     = params[:jwt]
            if @jwt
              # This is extracted for validation only
              @jwt_aud = @jwt[:aud]
              @jwt_iss = @jwt[:iss]
              @jwt_sid = @jwt[:sid]
              @jwt_sub = @jwt[:sub]
            end
          end
        end
      end
    end
  end
end
