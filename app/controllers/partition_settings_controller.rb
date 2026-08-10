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

class PartitionSettingsController < ApplicationController

  before_action :find_and_authorize, only: [:show, :edit, :update]

  def edit
    @partition_setting.DenyTargetAddresses = [''] if @partition_setting.DenyTargetAddresses.blank?
  end

  def update
    respond_to do |format|
      if @partition_setting.update(partition_setting_params)
        format.html { redirect_to @partition_setting, flash: { success: 'Settings were successfully updated.' } }
      else
        format.html { render :edit }
      end
    end
  end

  def show
    @title = "Details of '#{@partition_setting.partition.name}'"
  end

  private

  def find_and_authorize(id = params[:id])
    @partition_setting = PartitionSetting.readonly(false).find(id)
    authorize @partition_setting
  end

  def partition_setting_params
    params.require(:partition_setting).permit(PartitionSetting.config_params + [:DnsSearchDomainsBlob, :MaxEmbryonics_start, :MaxEmbryonics_rate, :MaxEmbryonics_max])
  end

end
