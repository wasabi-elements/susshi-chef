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

class ApplicationMailer < ActionMailer::Base
  layout 'mailer'

  def initialize
    super

    if Preference.any?
      unless (from = Preference.first.smtp_from).blank?
        self.headers["from"] = from
      end
    end

    @background_image = File.open(Rails.root.join("app/assets/images/mailer/background.jpg"), "rb") do |f|
      "data:image/jpg;base64,#{Base64.strict_encode64(f.read)}"
    end

    @logo = File.open(Rails.root.join("app/assets/images/mailer/logo.png"), "rb") do |f|
      "data:image/png;base64,#{Base64.strict_encode64(f.read)}"
    end
  end

  def activation_token
    user = params[:user]

    @username = user.fullname

    if user.is_a?(User)
      @activation_token = user.otp_activation_token
    elsif user.is_a?(SusshiUserLogin)
      @activation_token = user.totp_activation_token
    end

    mail(to: user.email, subject: "suSSHi Chef | Two-Factor Authentication - Your TOTP QR Code") do |format|
      format.html
      format.text
    end
  end

  def qr_code
    user = params[:user]

    @username = user.fullname

    if user.is_a?(User)
      @qr_code = user.otp_qr_image.to_data_url
      @totp_secret = user.otp_secret
    elsif user.is_a?(SusshiUserLogin)
      @qr_code = user.totp_qr_image.to_data_url
      @totp_secret = user.totp_secret
    end

    mail(to: user.email, subject: "suSSHi | Two-Factor Authentication - Your TOTP QR Code") do |format|
      format.html
      format.text
    end
  end

  def test_mail
    user = params[:user]

    @mailbox = File.open(Rails.root.join("app/assets/images/mailer/mailbox.png"), "rb") do |f|
      "data:image/png;base64,#{Base64.strict_encode64(f.read)}"
    end

    mail(to: user.email, subject: "suSSHi Chef | E-Mail Setup Completed")
  end

end
