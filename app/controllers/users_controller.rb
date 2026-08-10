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

class UsersController < ApplicationController

  before_action :find_and_authorize, only: [:show, :edit, :update, :edit_profile, :update_profile, :destroy, :reset_otp]
  around_action :swift_change_handler, only: [:create, :update, :destroy]

  def index
    @title = 'Admin Users'
    authorize :user, :index?

    @q = User.ransack(params_query)
    ransack_default_sort(@q, :username, :asc)
    @users = @q.result.page(params_page).per(params_per_page)
  end

  def show
    @title = "Details of '#{@user.fullname}'"
    respond_to do |format|
      format.html # show.html.erb
      format.json { render :json => @user }
    end
  end

  def send_activation_token
    find_and_authorize params[:user_id]

    begin
      ApplicationMailer.with(user: @user).activation_token.deliver!

      redirect_to users_path, :flash => { :success => 'Activation token was successfully sent.' }
    rescue StandardError => e
      Rails.logger.error e.message
      redirect_to users_path, :flash => { :error => 'Activation token was not successfully sent.' }
    end
  end

  def send_qr_code
    find_and_authorize params[:user_id]

    begin
      ApplicationMailer.with(user: @user).qr_code.deliver_now

      redirect_to users_path, :flash => { :success => 'QR code was successfully sent.' }
    rescue StandardError
      redirect_to users_path, :flash => { :error => 'QR code was not successfully sent.' }
    end
  end

  def new
    @title = "New Admin User"
    authorize :user, :new?
    @user = User.new
    respond_to do |format|
      format.html # new.html.erb
      format.json { render :json => @user }
    end
  end

  def edit
    @title = "Edit '#{@user.fullname}'"
  end

  def create
    authorize :user, :create?
    @user = User.new(user_params)

    respond_to do |format|
      if @user.save
        format.html { redirect_to users_path, flash: { :success => 'User was successfully created.' }}
      else
        format.html { render action: :new }
      end
    end
  end

  def update
    if params[:user][:password].blank? then
      params[:user].delete(:password)
      params[:user].delete(:password_confirmation)
    end

    respond_to do |format|
      if @user.update(user_params)
        format.html { redirect_to users_path, flash: { :success => 'User was successfully updated.' }}
      else
        format.html { render action: :edit }
      end
    end
  end

  def destroy
    @user.destroy

    respond_to do |format|
      format.html { redirect_to users_url, :flash => { :destroy => 'User was successfully deleted.' }}
      format.json { head :no_content }
    end
  end


  def edit_profile
    if @user.id != User.current_user.id
      flash[:error] = 'You are not allowed to change profile setting of another user.'
      redirect_to root_path
    end
  end


  def change_partition
    partition = User.current_user.partitions.find(params[:partition_id]) rescue nil

    unless partition.blank?
      User.set_partition_by_id(partition.id)
      cookies[:partition_id] = { value: partition.id, httponly: true, :expire_after => 12.hours, same_site: :lax, secure: Rails.env.production? }
    end

    unless partition.nil?
      flash[:notice] = "Partition has been changed to '#{partition.name}'."
    else
      flash[:error] = "Partition could not be changed. May be you've been removed from this Partition."
    end

    redirect_to main_app.root_path
  end


  def update_profile
    if @user.id != User.current_user.id
      flash[:error] = 'You are not allowed to change profile setting of another user.'
      redirect_to root_path
    end

    if (params[:user][:password] rescue nil).blank?
      params[:user].delete(:password)
      params[:user].delete(:password_confirmation)
    end

    unless @user.lek_self_service || @user.has_role_super?
      params[:user].delete(:log_encryption_key)
    end

    respond_to do |format|
      if @user.update(user_params_on_profile_update)
        if @user.saved_changes[:email] and Preference.first.otp_active?
          @qr_code = @user.otp_qr_image.to_data_url
          format.html { render :edit_profile_update_qr_code, :flash => { :notice => 'Profile was successfully updated.' }}
        else
          format.html { redirect_to root_path, :flash => { :notice => 'Profile was successfully updated.' }}
        end
      else
        format.html { render :action => "edit_profile" }
      end
    end
  end

  def reset_otp
    @user.enable_otp
    redirect_to users_path
  end

  private

  def find_and_authorize(id = params[:id])
    @user = User.readonly(false).find(id)
    authorize @user
  end

  def user_params
    params.require(:user).permit(:lek_self_service, :comment, :description, :email, :fullname, :log_encryption_key, :username, :password, :password_confirmation, :default_partition_id, :role, partition_ids: [] )
  end

  def user_params_on_profile_update
    params.require(:user).permit(:log_encryption_key, :password, :password_confirmation, :default_partition_id)
  end

  def partition_params
    params.permit(:user_id, :partition_id)
  end

  def swift_change_handler
    partitions_before = @user.present? ? @user.partitions.to_a : []

    yield

    return if @user.errors.any?
    return if @user.destroyed? && @user.log_encryption_key.blank?
    return if @user.previously_new_record? && (@user.log_encryption_key.blank? || @user.partitions.none?)

    partitions_after = @user.partitions.to_a

    actions = {added: [], removed: []}
    if @user.previously_new_record? || (@user.saved_change_to_log_encryption_key? && @user.log_encryption_key.present?)
      actions[:added] = partitions_after
    elsif @user.destroyed? || (@user.saved_change_to_log_encryption_key? && @user.log_encryption_key.blank?)
      actions[:removed] = partitions_before
    elsif @user.log_encryption_key.present?
      actions[:added] = partitions_after - partitions_before
      actions[:removed] = partitions_before - partitions_after
    end

    actions.each do |action, partitions|
      partitions.each do |partition|
        change_trail = ["#{action.to_s.titleize} Encryption Key for User '#{@user.username}'"]
        SwiftChange.create_for(partition, change_trail:)
      end
    end
  end
end
