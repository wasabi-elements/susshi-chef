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

class SusshiUserLoginsController < ApplicationController

  before_action :find_and_authorize, only: [:show, :edit, :unlock, :update, :destroy]

  def show
    @title = "Details of '#{@susshi_user_login.username}'"
  end

  def new
    @title = 'New Gateway User'
    authorize :susshi_user, :new?
    @partition = Partition.find(current_user.partition.id)
    @susshi_user_login = SusshiUserLogin.new(partition: @partition)
    prepare_form(@susshi_user_login)
  end

  def edit
    @title = "Edit '#{@susshi_user_login.username}'"
    prepare_form(@susshi_user_login)
  end

  def create
    authorize :susshi_user, :create?
    remove_empty_params(:susshi_user_keys_attributes, :public_blob)
    assist = params[:susshi_user_login].delete(:assist) || {}
    _params = susshi_user_login_params
    _params.delete(:password) if _params[:password].blank?
    @susshi_user_login = SusshiUserLogin.new(_params)
    if @susshi_user_login.save
      case assist[:totp]
        when 'activate'
          @susshi_user_login.generate_totp_activation_token!
        when 'secret'
          @susshi_user_login.generate_totp_secret!
        when 'deactivate'
          @susshi_user_login.deactivate_totp!
      end

      redirect_to susshi_users_path, flash: { :success => 'Gateway User was successfully created.' }
    else
      prepare_form(@susshi_user_login)
      render :new
    end
  end

  def update
    remove_empty_params(:susshi_user_keys_attributes, :public_blob)
    assist = params[:susshi_user_login].delete(:assist) || {}
    _params = susshi_user_login_params
    _params.delete(:password) if _params[:password].blank?
    if @susshi_user_login.update(_params)
      @susshi_user_login.update_attribute(:password, nil) if (assist[:password_remove] == '1')
      case assist[:totp]
        when 'activate'
          @susshi_user_login.generate_totp_activation_token!
        when 'secret'
          @susshi_user_login.generate_totp_secret!
        when 'deactivate'
          @susshi_user_login.deactivate_totp!
      end

      respond_to do |format|
        format.html { redirect_to susshi_users_path, flash: { :success => 'Gateway User was successfully updated.' } }
        format.js   { render js: 'location.reload();' }
      end
    else
      prepare_form(@susshi_user_login)
      render :edit
    end
  end

  def destroy
    @susshi_user_login.destroy
    redirect_to susshi_users_path, :flash => { :destroy => 'Gateway User was successfully deleted.' }
  end

  def send_activation_token
    find_and_authorize params[:susshi_user_login_id]

    begin
      ApplicationMailer.with(user: @susshi_user_login).activation_token.deliver_now

      redirect_to susshi_users_path, :flash => { :success => 'Activation token was successfully sent.' }
    rescue StandardError
      redirect_to susshi_users_path, :flash => { :error => 'Activation token was not successfully sent.' }
    end
  end

  def send_qr_code
    find_and_authorize params[:susshi_user_login_id]

    begin
      ApplicationMailer.with(user: @susshi_user_login).qr_code.deliver!

      redirect_to susshi_users_path, :flash => { :success => 'QR code was successfully sent.' }
    rescue StandardError => e
      Rails.logger.error e.message
      redirect_to susshi_users_path, :flash => { :error => 'QR code was not successfully sent.' }
    end
  end

  def unlock
    swift_susshi_user = SwiftSusshiUser.find_by(id: @susshi_user_login.id)

    if swift_susshi_user
      swift_susshi_user.auth_successful!

      redirect_to susshi_users_path, :flash => { :success => 'Gateway User was successfully unlocked.' }
    else
      redirect_to susshi_users_path, :flash => { :destroy => 'Gateway User was not found.' }
    end
  end


  private

  def find_and_authorize(id = params[:id])
    @susshi_user_login = SusshiUserLogin.readonly(false).where(partition_id: current_user.partition.id).find(id)
    authorize @susshi_user_login
  end

  def susshi_user_login_params
    params.require(:susshi_user_login).permit(:partition_id, :username, :fullname, :email, :active, :ShellLogin, :password, :password_confirmation,
                                              assist: [ :password_remove, :totp ], susshi_user_group_ids: [], susshi_user_keys_attributes: [:id, :public_blob, :title, :_destroy])
  end

  def remove_empty_params(relation, field)
    params[:susshi_user_login][relation.to_s].each do |key, data|
      if data[field.to_s].blank? then
        params[:susshi_user_login][relation.to_s][key]['_destroy'] = true
      end
    end unless params[:susshi_user_login][relation.to_s].nil?
  end

  def prepare_form(object = nil)
    if object
      object.susshi_user_keys.new({}) unless object.susshi_user_keys.any?
    end
    @show_totp_fields = Preference.totp_secret_key_set?
  end

end
