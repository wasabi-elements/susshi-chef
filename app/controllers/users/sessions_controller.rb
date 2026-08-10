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

class Users::SessionsController < Devise::SessionsController

  def create
    if user_exist_and_has_valid_password?
      user = User.find_by(username: params[:user][:username])
      if Preference.first.otp_active?
        if user.otp_activation_token.blank?
          if user.otp_required_for_login
            return render :otp
          end
        else
          return render :otp_activation
        end
      else
        create_session(user)
        return
      end
    end
    redirect_to new_user_session_path
  end

  def user_exist_and_has_valid_password?
    if user = User.find_by(username: params[:user][:username])
      if user.valid_password?(params[:user][:password])
        session[:temp_user_id] = user.id
        return true
      end
    end
    flash[:error] = 'Invalid username or password.'
    return false
  end

  def verify_otp_activation
    user = User.find_by(id: session[:temp_user_id])

    begin
      if user.validate_otp_activation(params[:otp_activation])
        user.generate_otp_secret
        @otp_qr_code = user.otp_qr_image.to_data_url
        @otp_secret = user.otp_secret

        render :otp_qr
      else
        flash[:error] = 'Invalid Activation Token'

        render :otp_activation
      end
    rescue ActiveRecord::Encryption::Errors::Decryption
      flash[:error] = 'Invalid Activation Token or Encryption Key'

      render :otp_activation
    rescue OpenSSL::Cipher::CipherError
      flash[:error] = 'Invalid Activation Token or Encryption Key'

      render :otp_activation
    end
  end

  def verify_otp
    user = User.find_by(id: session[:temp_user_id])

    begin
      if user.validate_and_consume_otp!(params[:otp_attempt], otp_secret: user.otp_secret)
        create_session(user)
      else
        if user.current_otp == params[:otp_attempt]
          flash[:error] = 'One-Time Password already consumed'
        else
          flash[:error] = 'Invalid One-Time Password'
        end

        render :otp
      end
    rescue ActiveRecord::Encryption::Errors::Decryption
      flash[:error] = 'Invalid One-Time Password or Encryption Key'

      render :otp
    rescue OpenSSL::Cipher::CipherError
      flash[:error] = 'Invalid One-Time Password or Encryption Key'

      render :otp
    end
  end

  def commit_otp
    user = User.find_by(id: session[:temp_user_id])
    user.activate_otp

    return render :otp
  end

  private

  def create_session(user)
    sign_in(user)
    session.delete(:temp_user_id)
    flash.discard
    flash[:notice] = 'Welcome to suSSHi Chef'
    respond_with user, location: after_sign_in_path_for(user)
  end

end