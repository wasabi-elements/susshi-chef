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

class ErrorsController < ApplicationController
  def not_found
    respond_to do |format|
      format.html { render status: 404 }
      format.json { render json: { errors: [ { message: 'Page not found. Please check URL path.' }]} }
      format.any  { head 404 }
    end
  end

  def internal_server_error
    render(status: 500)
  end

  def forbidden
    respond_to do |format|
      format.html { render status: 403 }
      format.json { render json: { errors: [ { message: 'Forbidden.' }]} }
      format.any  { head 403 }
    end
  end
end
