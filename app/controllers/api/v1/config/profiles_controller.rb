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

module Api::V1::Config
  class ProfilesController < ApiController

    wrap_parameters :profile, include: [:name, :description, :client_auth_set_id, :LoggingMask, :MaxSessionIdleSeconds, :MaxSessionSeconds,
                                        :SSHAgentForward, :SSHCommandExecs, :SSHInteractive, :SSHLocalForwards, :SSHRemoteForwards,
                                        :SSHSecureCopy, :SSHSecureFileTransfer, :SSHSessionSubsystems, :SSHSocketForward, :SSHTcpForwardSsh,
                                        :SSHX11Forward, :TargetHostKeyLearning, :TargetPreferredAuthentications, :UsePreservedPassword]

    private

    def strong_params
      params.require(:profile).permit(:name, :description, :client_auth_set_id, :LoggingMask, :MaxSessionIdleSeconds, :MaxSessionSeconds,
                                      :SSHAgentForward, :SSHInteractive, :SSHSecureCopy, :SSHSecureFileTransfer, :SSHSocketForward, :SSHTcpForwardSsh,
                                      :SSHX11Forward, :TargetHostKeyLearning, :UsePreservedPassword, TargetPreferredAuthentications: [],
                                      SSHCommandExecs: [], SSHLocalForwards: [], SSHRemoteForwards: [], SSHSessionSubsystems: [])
    end

    def rack_reducers
      super + [
          ->(description:) { where(api_query_search_string(:description, description)) }
      ]
    end

  end
end