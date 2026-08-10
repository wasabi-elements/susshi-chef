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

class TargetDomainsController < ApplicationController

  require 'resolv'

  before_action :find_and_authorize, only: [:show, :edit, :update, :destroy]

  def show
    @title = "Details of '#{@target_domain.domainname}'"
  end

  def show_host
    authorize :target_domain, :show?
    @target_host = Target.find(params[:id])
  end

  def new
    authorize :target_domain, :new?
    @partition = Partition.find(current_user.partition.id)
    @target_domain = TargetDomain.new(partition: @partition)
    prepare_form(@target_domain)
  end

  def edit
    @title = "Edit '#{@target_domain.domainname}'"
    prepare_form(@target_domain)
  end

  def create
    authorize :target_domain, :create?

    @target_domain = TargetDomain.new(target_params)

    if @target_domain.save
      redirect_to targets_path, flash: { success: 'Domain Target was successfully created.' }
    else
      prepare_form(@target_domain)
      render :new
    end
  end

  def update
    if @target_domain.update(target_params)
      respond_to do |format|
        format.html { redirect_to targets_path, flash: { success: 'Domain Target was successfully updated.' } }
        format.js   { render js: 'location.reload();' }
      end
    else
      prepare_form(@target_domain)
      render :edit
    end
  end

  def destroy
    @target_domain.destroy
    redirect_to targets_url, flash: { destroy: 'Domain Target was successfully destroyed.' }
  end

  private

  def find_and_authorize(id = params[:id])
    @target_domain = TargetDomain.readonly(false).find(id)
    authorize @target_domain
  end

  def target_params
    params.require(:target_domain).permit(:partition_id, :proxy_id, :domainname, :description, :active, { target_group_ids: [] })
  end

  def remove_empty_params(relation, field)
    params[:target_domain][relation.to_s].each do |key, data|
      if data[field.to_s].blank? then
        params[:target_domain][relation.to_s][key]['_destroy'] = true
      end
    end unless params[:target_domain][relation.to_s].nil?
  end

  def prepare_form(object = nil)
  end


end


