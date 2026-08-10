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

class ApiTokensController < ApplicationController

  before_action :find_and_authorize, only: [:show, :edit, :update, :destroy]

  def index
    authorize :api_token, :index?

    @q = ApiToken.ransack(params_query)
    ransack_default_sort(@q, :application, :asc)
    @api_tokens = @q.result.page(params_page).per(params_per_page)
  end

  def show
    @title = "Details of '#{@api_token.application}'"

    respond_to do |format|
      format.html # show.html.erb
      format.json { render :json => @api_token }
    end
  end

  def new
    authorize :api_token, :new?

    @api_token = ApiToken.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render :json => @api_token }
    end
  end

  def edit
    @title = "Edit '#{@api_token.application}'"
  end

  def create
    authorize :api_token, :create?

    @api_token = ApiToken.new(api_token_params)
    @api_token_hex = SecureRandom.hex(32)
    @api_token.token_digest = Digest::SHA256.hexdigest @api_token_hex

    respond_to do |format|
      if @api_token.save
        @title = "API Token for #{@api_token.application}"
        flash[:success] = 'API Token was successfully created.'
        format.html { render }
      else
        format.html { render action: :new }
      end
    end
  end

  def update
    respond_to do |format|
      if @api_token.update(api_token_params)
        format.html { redirect_to api_tokens_path, flash: { :success => 'API Token was successfully updated.' }}
      else
        format.html { render action: :edit }
      end
    end
  end

  def destroy
    @api_token.destroy

    respond_to do |format|
      format.html { redirect_to api_tokens_url, :flash => { :destroy => 'API Token was successfully deleted.' }}
      format.json { head :no_content }
    end
  end

  private

  def find_and_authorize(id = params[:id])
    @api_token = ApiToken.readonly(false).find(id)
    authorize @api_token
  end

  def api_token_params
    _params = params.require(:api_token).permit(:partition_id, :application, :comment, :description, assist: [:permissions_preset], permissions: {})
    _params.delete(:assist)  # Permissions Preset
    _params['permissions'].each do |pkey, perm|
      _params['permissions'][pkey].transform_values!{|value| value.to_i == 1}
    end
    _params
  end

end
