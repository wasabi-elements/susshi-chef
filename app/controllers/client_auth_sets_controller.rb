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

class ClientAuthSetsController < ApplicationController

  before_action :find_and_authorize, only: [:show, :edit, :update, :destroy]

  def index
    authorize :client_auth_set, :index?

    @q = ClientAuthSet.includes([:bastion_profiles, :profiles, :publickey_client_auth, :interactive_client_auth]).where(partition_id: current_user.partition.id).ransack(params_query)
    ransack_default_sort(@q, :name, :asc)
    @client_auth_sets = @q.result.page(params_page).per(params_per_page)
  end

  def show
    @title = "Details of '#{@client_auth_set.name}'"
  end

  def new
    authorize :client_auth_set, :new?
    @partition = Partition.find(current_user.partition.id)
    @client_auth_set = ClientAuthSet.new(partition: @partition)
    prepare_form(@client_auth_set)
    @title = 'New Client Auth Set'
    render :new
  end

  def edit
    @title = "Edit '#{@client_auth_set.name}'"
    prepare_form(@client_auth_set)
  end

  def create
    authorize :client_auth_set, :create?
    @partition = Partition.find(current_user.partition.id)
    @client_auth_set = ClientAuthSet.new(partition: @partition)
    @client_auth_set.assign_attributes(client_auth_set_params)

    if @client_auth_set.save
      redirect_to client_auth_sets_path, flash: { success: 'Client Auth Set was successfully created.' }
    else
      prepare_form(@client_auth_set)
      render :new
    end
  end


  def create_wrong
    authorize :client_auth_set, :create?
    ClientAuthSet.transaction do
      @partition = Partition.find(current_user.partition.id)
      @client_auth_set = ClientAuthSet.new(partition: @partition)
      _params = client_auth_set_params
      _params.delete(:publickey_client_auth_attributes)
      _params.delete(:interactive_client_auth_attributes)
      @client_auth_set.assign_attributes(_params)
      @client_auth_set.assign_attributes(client_auth_set_params)

      if @client_auth_set.save
        redirect_to client_auth_sets_path, flash: { success: 'Client Auth Set was successfully created.' }
      else
        prepare_form(@client_auth_set)
        render :new
      end
    end
  end

  def update
    if @client_auth_set.update(client_auth_set_params)
      respond_to do |format|
        format.html { redirect_to client_auth_sets_path, flash: { success: 'Client Auth Set was successfully updated.' } }
        format.js   { render js: 'location.reload();' }
      end
    else
      prepare_form(@client_auth_set)
      render :edit
    end
  end

  def destroy
    @client_auth_set.destroy
    redirect_to client_auth_sets_url, flash: { destroy: 'Client Auth Set was successfully destroyed.' }
  end

  private

    def find_and_authorize(id = params[:id])
      @client_auth_set = ClientAuthSet.readonly(false).find(id)
      authorize @client_auth_set
    end


    def client_auth_set_params
      params.require(:client_auth_set).permit(:partition_id, :name, :description, :comment,
                                              :cache_enabled, :cache_idle_time, :max_cache_time, :cache_refresh, :cache_whitelist_text,
                                              :auth_logic, :auth_logic_cached,
                                              publickey_client_auth_attributes: {},
                                              interactive_client_auth_attributes: {})
    end


    def prepare_form(object = nil)
      if object
        if params[:action] == 'newx'
          object.build_publickey_client_auth({type: ClientAuth::Publickey}) unless object.publickey_client_auth
          object.build_interactive_client_auth({type: ClientAuth::Password}) unless object.interactive_client_auth
        else
          object.build_publickey_client_auth({}) unless object.publickey_client_auth
          object.build_interactive_client_auth({}) unless object.interactive_client_auth
        end
      end
    end

end


