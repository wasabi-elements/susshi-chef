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

class SubscriptionsController < ApplicationController

  def index
    authorize :subscription, :edit?
    @subscription = Subscription.instance
    @subscription.validate
    @title = "Subscription"

    respond_to do |format|
      if @subscription.valid?
        format.html { render :edit }
      else
        format.html { render :new }
      end
    end
  end

  def create
    authorize :subscription, :edit?

    @subscription = Subscription.new(subscription_params)
    @errors = @subscription.load

    respond_to do |format|
      if (@errors.blank? && @subscription.save)
        format.html { redirect_to subscriptions_path, flash: { :success => "Subscription activated!" } }
      else
        format.html { render :new }
      end
    end
  end

  def update
    authorize :subscription, :edit?

    @subscription = Subscription.instance

    respond_to do |format|
      load_errors = @subscription.load
      if (load_errors.nil? && @subscription.save) == true
        format.html { redirect_to subscriptions_path, flash: { :success => "Subscription refreshed successfully!" } }
      else
        format.html { render :edit, locals: { load_errors: }, flash: { :error => "Subscription refresh failed!", } }
      end
    end
  end

  def destroy
    authorize :subscription, :edit?

    Subscription.destroy_all
    redirect_to subscriptions_path, flash: { :success => 'Subscription deleted!' }
  end

  private
  def subscription_params
    params.require(:subscription).permit(:subscription_key)
  end

end