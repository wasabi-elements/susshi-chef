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

class PreferencePolicy < ApplicationPolicy

  def edit?
    user.has_role_super?
  end

  alias_method :server_ssl?, :edit?
  alias_method :csr?, :edit?
  alias_method :create_csr?, :edit?
  alias_method :destroy_csr?, :edit?
  alias_method :certificate?, :edit?
  alias_method :create_certificate?, :edit?
  alias_method :destroy_certificate?, :edit?
  alias_method :activate_certificate?, :edit?
  alias_method :upload_server_ssl?, :edit?
  alias_method :send_test_mail?, :edit?

end
