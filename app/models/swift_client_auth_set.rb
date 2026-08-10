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

class SwiftClientAuthSet < Swift

  belongs_to :partition

  #-- Instance methods

  def auth_hook_response_params(auth_hook, params, response)
    cached = false

    if self.cache_enabled? && params.respond_to?(:client_ip) && params.respond_to?(:susshi_user)
      cached = SwiftIpCaching.lookup(
        create:             false,
        refresh:            self.cache_refresh,
        source_ip:          params.client_ip,
        swift_susshi_user:  SwiftSusshiUser.find_by(name: params.susshi_user),
        cache_idle_time:    self.cache_idle_time,
        max_cache_time:     self.max_cache_time,
        whitelist:          self.cache_whitelist,
        client_auth_set_id: self.id
      )
    end

    response[:ClientAuthsRequired] = cached ? self.required_auths_cached : self.required_auths
    response[:ClientAuthsPreferred] = self.preferred_auths

    if response[:ClientAuthsRequired].include? 'interactive'
      unless ((client_auth = self.interactive_auth_properties['type'].constantize) rescue nil).nil?
        unless client_auth.operational?(self.interactive_auth_properties)
          response[:ClientAuthsRequired] = ['publickey']

          unless self.interactive_auth_properties['fallback_message'].blank?
            response[:Configuration] ||= {}
            response[:Configuration][:Banner] = self.interactive_auth_properties['fallback_message']
          end
        end
      end
    end

    response[:Configuration] ||= {}
    response[:Configuration].merge!(
      ClientGatewayAuthTitle:       self.interactive_auth_properties['kbd_int_auth_title'],
      ClientGatewayAuthInstruction: self.interactive_auth_properties['kbd_int_auth_instruction'],
      ClientGatewayAuthPrompt:      self.interactive_auth_properties['kbd_int_auth_prompt']
    )
    response[:Configuration].compact!

    if self.interactive_auth_properties['type'] == "ClientAuth::OpenidConnect"
      unless cached
        # Not cached, create an Auth Ticket
        # Max store time for Auth Ticket
        max_store_time = auth_hook.response[:Target].map { |_, values| values[:MaxSessionSeconds] }.max

        ticket = SwiftAuthTicket.create_ticket(partition_id:          auth_hook.partition_id,
                                               susshi_user_id:        auth_hook.susshi_user.id,
                                               susshi_uniqid:         params.susshi_uniq_id,
                                               session_end_on_logout: self.interactive_auth_properties["session_end_on_logout"],
                                               state:                 :issued,
                                               source_ip:             params.client_ip,
                                               max_store_time:)

        if ticket
          response[:Configuration][:ClientGatewayAuthInstruction].gsub!(/%secret%/, ticket.secret)
        else
          raise "Swift Auth Ticket couldn't be created"
        end
      else
        # Cached, find ticket and add susshi_uniqid to it
        SwiftAuthTicket.find_by(partition_id:          auth_hook.partition_id,
                                susshi_user_id:        auth_hook.susshi_user.id,
                                source_ip:             params.client_ip,
                                session_end_on_logout: self.interactive_auth_properties["session_end_on_logout"]
        )&.add_susshi_uniqid(params.susshi_uniq_id)
      end
    end

    response
  end

  def cache_enabled?
    self.cache_properties['cache'] == 'enabled'
  end

  def cache_idle_time
    self.cache_properties['idle_time']
  end

  def max_cache_time
    self.cache_properties['max_time']
  end

  def cache_refresh
    self.cache_properties['refresh']
  end

  def cache_whitelist
    self.cache_properties['whitelist'] || []
  end

  def operational?
    return true if self.interactive_auth_properties.blank?
    return true unless self.interactive_auth_properties.dig("status", "expires_at").is_a? Integer
    return true unless self.interactive_auth_properties.dig("status", "expires_at") > Time.now.to_i
    return true unless [true, false].include? self.interactive_auth_properties.dig("status", "operational")

    self.interactive_auth_properties.dig("status", "operational")
  end

end
