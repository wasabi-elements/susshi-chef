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

# These helper methods can be called in your template to set variables to be used in the layout
# This module should be included in all views globally,
# to do so you may need to add this line to your ApplicationController
#   helper :layout
module SubscriptionsHelper
  def subscription_content_for_navbar(subscription)
    if subscription.valid?
      if @subscription.expires_soon?
        content_for(:navbar_subscription, "Subscription expires soon")
      else
        content_for(:navbar_subscription, "Mega Supporter")
        content_for(:navbar_subscription_icon, "fa fa-heart")
      end
    else
      if @subscription.expired?
        content_for(:navbar_subscription, "Subscription expired")
      elsif subscription.vendor
        content_for(:navbar_subscription, "Subscription not valid")
      else
        content_for(:navbar_subscription, "No Subscription")
      end
    end
  end
end

              
