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

class PreferencesController < ApplicationController

  respond_to :html, :csr, :pem, :key, :p12

  before_action :find_and_authorize

  def edit
  end

  def update
    respond_to do |format|
      if @preference.update(preferences_params)

        if @preference.saved_changes[:admin_auth_method] and @preference.otp_active?
          current_user.generate_otp_secret
          current_user.activate_otp
          @qr_code = current_user.otp_qr_image.to_data_url

          flash[:success] = 'Preferences were successfully updated.'
          format.html { render :otp_activated }
        elsif @preference.saved_changes[:smtp_settings]
          @active_tab = :mail
          flash[:success] = 'Preferences were successfully updated.'
          format.html { render :edit }
        else
          format.html { redirect_to :root, flash: { :success => 'Preferences were successfully updated.' } }
        end
      else
        flash[:error] = 'Preferences have not been updated. Something went wrong.'
        format.html { render :edit }
      end
    end
  end

  def send_test_mail
    @result = {}

    begin
      ApplicationMailer.with(user: current_user).test_mail.deliver!

      @result[:status] = :success
      @result[:message] = "Success!"
    rescue StandardError => e
      @result[:status] = :error
      @result[:message] = e.message
    end

    render js: "toastr[\"#{@result[:status]}\"](\"#{helpers.escape_javascript(@result[:message])}\", \"E-Mail Setup\", {positionClass: \"toast-bottom-right\"});", layout: false
  end

  def server_ssl
  end

  def csr
    respond_to do |format|
      format.csr {
        send_data(@preference.server_csr.data, :filename => "#{request.host}.csr")
      }
    end
  end

  def create_csr
    SSL::Server.create_csr(params['ssl'])
    redirect_to :server_ssl_preferences
  end

  def destroy_csr
    @preference.server_csr.try(:destroy)
    @preference.server_key.try(:destroy)
    @preference.server_certificate.try(:destroy)
    redirect_to :server_ssl_preferences, flash: { success: 'CSR were successfully deleted.' }
  end

  def certificate
    respond_to do |format|
      format.crt {
        send_data(@preference.server_csr.data, :filename => 'susshi-chef-server.crt')
      }
    end
  end

  def create_certificate
    if params.dig(:ssl, :file).nil?
      redirect_to :server_ssl_preferences, flash: { error: 'Certificate import failed. You missed to selected a certificate.' }
    else
      pem = params['ssl']['file'].read
      if SSL::Server.validate_uploaded_certificate(pem)
        certificate = OpenSSL::X509::Certificate.new pem
        SSL::Server.replace_server_certificate(certificate.to_pem)
        redirect_to :server_ssl_preferences, flash: { success: 'Certificate were successfully uploaded.' }
      else
        redirect_to :server_ssl_preferences, flash: { error: 'Certificate import failed. Please check the certificate.' }
      end
    end
  end

  def upload_server_ssl
    rc = false

    if params['ssl']['file_p12']
      # we got one p12 file - NIY

    else
      # we got a public and private key pem files
      if params['ssl']['file_private_pem']
        priv = params['ssl']['file_private_pem'].read
        if params['ssl']['file_certificate_pem']
          cert = params['ssl']['file_certificate_pem'].read
          if SSL::Server.validate_uploaded_certificate(cert, priv, params['ssl']['passphrase'])
            unless params['ssl']['passphrase'].blank?
              privkey = OpenSSL::PKey::RSA.new priv, params['ssl']['passphrase']
              priv = privkey.to_s
            end
            rc = true
          end
        end
      end
    end

    if rc
      SSL::Server.replace_server_certificate(cert)
      SSL::Server.replace_server_key(priv)
      redirect_to :server_ssl_preferences, flash: { success: 'Import was successful.' }
    else
      redirect_to :server_ssl_preferences, flash: { error: 'Import failed. May be you have specified no or a wrong passphrase?' }
    end

  end

  def activate_certificate
    if SSL::Server.activate_certificate
      redirect_to :server_ssl_preferences, flash: { success: 'Key / Certificate were successfully activated.' }
    else
      redirect_to :server_ssl_preferences, flash: { error: 'Key / Certificate were not activated. Something went wrong.' }
    end
  end

  def destroy_certificate
    @preference.server_certificate.destroy
    redirect_to :server_ssl_preferences, flash: { success: 'Certificate were successfully deleted.' }
  end

  private

  def find_and_authorize
    @preference = Preference.first
    authorize @preference
  end

  def preferences_params
    params.require(:preference).permit(:admin_auth_method, :admin_auth_realm, :login_banner,
                                       :expire_password_after, :flat_access_policies, :max_idle_time, :max_session_time, :password_archiving_count, :password_length,
                                       :ui_ssl_client_cert_verify, :ui_ssl_client_cert_ca, :ui_ssl_client_cert_cn_pattern, :ui_ssl_client_cert_verify_depth,
                                       :syslog_server1, :syslog_server2, :syslog_server3, :syslog_server4, :syslog_proto, :syslog_port,
                                       :syslog_retention_days, :session_report_retention_days,
                                       :smtp_address, :smtp_port, :smtp_domain, :smtp_from, :smtp_user_name, :smtp_password, :smtp_authentication, :smtp_encryption, :smtp_openssl_verify_mode,
                                       :frontend_totp_issuer, :frontend_totp_show_on_ui)
  end

end
