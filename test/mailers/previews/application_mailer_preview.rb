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

# Preview all emails at http://localhost:3000/rails/mailers/application_mailer
class ApplicationMailerPreview < ActionMailer::Preview

  def activation_code
    user = User.new(
      name: "John Doe",
      username: "john.doe",
      email: "john.doe@example.com",
      otp_activation_token: SecureRandom.hex(32)
    )

    ApplicationMailer.with(user:).activation_token
  end

  def qr_code
    user = SusshiUserLogin.new(
      fullname: "John Doe",
      name: "john.doe",
      email: "john.doe@example.com",
      totp_secret: ROTP::Base32.random_base32(32),
      totp_state: "active"
    )

    ApplicationMailer.with(user:).qr_code
  end

  def test_mail
    user = User.new(
      name: "John Doe",
      username: "john.doe",
      email: "john.doe@example.com"
    )

    ApplicationMailer.with(user: user).test_mail
  end

end
