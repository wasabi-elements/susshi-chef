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

module ApiTokensHelper

  def permissions(object, klass, long_form = false)
    concat content_tag(:span, long_form ? 'Create' : 'C', class: "label label-#{object.has_permission?(klass, :create) ? 'info':'disable'} label-outlined", title: 'Create')
    concat content_tag(:span, long_form ? 'Read' : 'R', class: "label label-#{object.has_permission?(klass, :read) ? 'primary':'disable'} label-outlined", title: 'Read')
    concat content_tag(:span, long_form ? 'Update' : 'U', class: "label label-#{object.has_permission?(klass, :update) ? 'warning':'disable'} label-outlined", title: 'Update')
    concat content_tag(:span, long_form ? 'Delete' : 'D', class: "label label-#{object.has_permission?(klass, :destroy) ? 'danger':'disable'} label-outlined", title: 'Delete')
  end

  def susshi_user_permissions(object, klass, long_form = false)
    permissions(object, klass, long_form)
    concat content_tag(:span, long_form ? 'TOTP' : 'T', class: "label label-#{object.has_permission?(klass, :totp) ? 'primary':'disable'} label-outlined", title: 'Include OTP attributes in Object Data')
  end

  def operations_permissions(object, klass, long_form = false)
    concat content_tag(:span, long_form ? 'Activate' : 'A', class: "label label-#{object.has_permission?(klass, :update) ? 'warning':'disable'} label-outlined", title: 'Activate')
    concat content_tag(:span, long_form ? 'Read' : 'R', class: "label label-#{object.has_permission?(klass, :read) ? 'primary':'disable'} label-outlined", title: 'Read')
  end

  def healths_permissions(object, klass, long_form = false)
    concat content_tag(:span, long_form ? 'Request' : 'R', class: "label label-#{object.has_permission?(klass, :read) ? 'primary':'disable'} label-outlined", title: 'Read')
  end

  def dotp_permissions(object, klass, long_form = false)
    concat content_tag(:span, long_form ? 'Validate' : 'V', class: "label label-#{object.has_permission?(klass, :read) ? 'primary':'disable'} label-outlined", title: 'Validate DOTP tickets')
  end

  def oidc_permissions(object, klass, long_form = false)
    concat content_tag(:span, long_form ? 'Validate' : 'V', class: "label label-#{object.has_permission?(klass, :read) ? 'primary' : 'disable'} label-outlined", title: 'Validate OIDC secrets')
    concat content_tag(:span, long_form ? 'Back-Channel Logout' : 'L', class: "label label-#{object.has_permission?(klass, :destroy) ? 'primary' : 'disable'} label-outlined", title: 'OIDC Back-Channel Logout')
  end

end
