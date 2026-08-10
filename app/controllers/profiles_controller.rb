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

class ProfilesController < ApplicationController

  before_action :find_and_authorize, only: [:show, :edit, :update, :destroy, :clone]

  def index
    @title = 'Access Profiles'
    authorize :profile, :index?

    @q = Profile.includes([:accesses, :client_auth_set]).where(partition_id: current_user.partition.id).ransack(params_query)
    ransack_default_sort(@q, :name, :asc)
    @profiles = @q.result.page(params_page).per(params_per_page)
  end

  def show
    @title = "Details of '#{@profile.name}'"
    set_logging_mask
  end

  def new
    @title = 'New Access Profile'
    authorize :profile, :new?
    @partition = Partition.find(current_user.partition.id)
    @profile = Profile.new(partition: @partition)
    prepare_form
  end

  def edit
    @title = "Edit '#{@profile.name}'"
    prepare_form
  end

  def clone
    authorize :profile, :edit?
    @profile = @profile.dup
    @profile.name = "#{@profile.name}-clone"
    prepare_form
  end

  def create
    authorize :profile, :create?
    params[:profile][:LoggingMask] = logging_mask(params[:profile][:lm])
    _params = profile_params
    _params.delete(:TargetPassword) if _params[:TargetPassword].blank?
    @profile = Profile.new(_params)

    if @profile.save
      redirect_to profiles_path, flash: { success: 'Profile was successfully created.' }
    else
      prepare_form
      render :new
    end
  end

  def update
    params[:profile][:LoggingMask] = logging_mask(params[:profile][:lm])
    _params = profile_params
    _params.delete(:TargetPassword) if _params[:TargetPassword].blank?
    if @profile.update(_params)
      respond_to do |format|
        format.html { redirect_to profiles_path, flash: { success: 'Profile was successfully updated.' } }
        format.js   { render js: 'location.reload();' }
      end
    else
      prepare_form
      render :edit
    end
  end

  def destroy
    @profile.destroy
    redirect_to profiles_path, flash: { destroy: 'Profile was successfully destroyed.' }
  end

  private

  def find_and_authorize(id = params[:id] || params[:profile_id])
    @profile = Profile.readonly(false).find(id)
    authorize @profile
  end

  def prepare_form
    set_logging_mask
  end

  def set_logging_mask
    mask = @profile ? @profile.LoggingMask : 65535

    @logging_mask = {
        session: mask & 1 > 0,
        tr_target: mask & 2 > 0,
        tr_client: mask & 4 > 0,
        filetransfer: mask & 8 > 0,
        portforward: mask & 16 > 0,
        x11: mask & 32 > 0,
        agent: mask & 64 > 0,
        socket: mask & 128 > 0
    }
  end

  def logging_mask(p)
    i=-1
    p.keys.map { |key| (p[key] == '1' ? 1 : 0) << (i+=1)}.inject(0){|sum, x| sum + x}
  end

  def profile_params
    params.require(:profile).permit(:partition_id, :client_auth_set_id, :name, :description, :LogEncryption, :LoggingMask, :MaxSessionSeconds,
                                    :MaxSessionIdleSeconds, :SSHAgentForward, :SSHSecureFileTransfer, :SSHX11Forward, :SSHInteractive,
                                    :SSHSecureCopy, :SSHSocketForward, :SSHTcpForwardSsh, :TargetHostKeyLearning, :TargetPreferredAuthentication,
                                    :TargetPassword, :TargetPassword_confirmation, :TargetPasswordSource, :TargetUser, :TargetPasswordCheckIdentity, :TargetPasswordLength,
                                    :TargetPasswordValidSeconds, :TargetPasswordContinue,
                                    SSHSessionSubsystems: [], SSHLocalForwards: [], SSHRemoteForwards: [], SSHCommandExecs: [],
                                    TargetPreferredAuthentications: [],
                                    lm: [:session, :tr_client, :tr_target, :filetransfer, :portforward, :x11, :agent, :socket])
  end

end


