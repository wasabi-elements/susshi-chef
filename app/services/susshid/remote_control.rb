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

class Susshid::RemoteControl

  #-- Instance variables
  attr_accessor :session

  class << self
    def auth_grant(ticket)
      begin
        results = ticket.susshi_uniqids.map do |susshi_uniqid|

          uniqid_hash = susshi_uniqid_to_hash(susshi_uniqid)
          gateway = SwiftGateway.find_by(identifier: uniqid_hash[:identifier])

          session(gateway&.id) do |session|
            session.exec!("auth-grant #{susshi_uniqid}")
          end
        end

        if results&.uniq&.count == 1
          JSON.parse(results.first)
        else
          { 'return' => 'failed', 'fail_reason' => 'some sessions failed' }
        end
      rescue
        { 'return' => 'failed', 'fail_reason' => 'unreachable' }
      end
    end

    def status(gateway_id)
      begin
        result = session(gateway_id) do |session|
          session.exec!('status')
        end
        JSON.parse(result)
      rescue
        { 'return' => 'failed', 'status' => 'unreachable' }
      end
    end

    def status_all(gateway_ids)
      ssh_args = default_ssh_args
      queue = Queue.new(SwiftGateway.where(id: gateway_ids))

      result = {}

      threads = (queue.size < 10 ? queue.size : 10).times.map do
        Thread.new do
          while (gateway = (queue.pop(true) rescue nil))
            args = ssh_args.dup.merge(
              port:     (gateway.sic_port || 22),
              key_data: [gateway.sic_ssh_private_key]
            )

            begin
              Net::SSH.start(gateway.sic_host, '#chef-remote#', args) do |session|
                result[gateway.id] = JSON.parse(session.exec!('status'))
              rescue StandardError
                { 'return' => 'failed' }
              end
            rescue StandardError
              result[gateway.id] = { 'return' => 'failed', 'status' => 'unreachable' }
            end
          end
        end
      end

      threads.map(&:join)

      result
    end

    def version(gateway_id)
      status(gateway_id)['software_version'] rescue nil
    end

    def version_uint32(gateway_id)
      gateway_version = version(gateway_id)
      gateway_version ? ((gateway_version.split('.').map{|x| "%02d" % x.to_i }.join('').to_i) rescue -1) : -1
    end

    def restart(gateway_id)
      result = session(gateway_id) do |session|
        session.exec!('restart')
      end
      JSON.parse(result)
    end

    def restart_all(partition_id)
      SwiftGateway.where(partition_id: partition_id).each do |gateway|
        begin
          restart(gateway.id)
        rescue
          nil
        end
      end
    end

    def shutdown(gateway_id)
      result = session(gateway_id) do |session|
        session.exec!('shutdown')
      end
      JSON.parse(result)
    end

    def suspend(gateway_id)
      result = session(gateway_id) do |session|
        session.exec!('suspend')
      end
      JSON.parse(result)
    end

    def unsuspend(gateway_id)
      result = session(gateway_id) do |session|
        session.exec!('unsuspend')
      end
      JSON.parse(result)
    end

    def terminate(session_report)
      gateway_identifier = session_report.susshi_uniqid.split('-')[2] rescue nil
      if gateway_identifier
        gateway = SwiftGateway.find_by_identifier(gateway_identifier)
        if gateway
          result = session(gateway.id) do |session|
            session.exec!("terminate #{session_report.susshi_uniqid}")
          end
          return JSON.parse(result)
        end
      end
      { 'return' => 'failed' }
    end

    def scan_hostkeys(gateway_id, ip_addresses, via_proxy_id = nil)

      # Max 32 slices to not overwhelm the gateway
      slice_size = ip_addresses.size / 32
      slice_size = 8 if slice_size < 8

      if gateway = SwiftGateway.find(gateway_id)
        unless gateway.sic_host.blank?
          if SwiftPartition.find(gateway.partition_id)
            threads = ip_addresses.in_groups_of(slice_size).map do |ips|

              # Throttle connections to gateway
              sleep 0.1

              # For each scan slice, start a new thread
              Thread.new do
                Rails.application.executor.wrap do
                  start_args = {
                    config:                     false,
                    use_agent:                  false,
                    non_interactive:            true,
                    keys_only:                  true,
                    port:                       (gateway.sic_port || 22),
                    timeout:                    3,
                    auth_methods:               %w(publickey),
                    keys:                       [],
                    key_data:                   [gateway.sic_ssh_private_key],
                    number_of_password_prompts: 0
                  }

                  Net::SSH.start(gateway.sic_host, '#chef-remote#', start_args) do |session|
                    session.exec!("scan-hostkeys #{ips.compact.join(' ')}")
                  end
                end
              end

            end
          end
        end
      end

      # Default result
      result = { 'command' => 'scan-hostkeys', 'hostkeys' => {}, 'return' => 'failed' }

      # Collect returned values from threads
      threads.compact.each do |thread|
        thread_result = JSON.parse(thread.value) rescue { 'return' => 'failed' }
        if thread_result['return'] == 'success'
          result['return'] = 'success'
          result['hostkeys'].merge!(thread_result['hostkeys']).compact!
        end
      end

      result
    end

    def status_proxy(gateway_id, proxy_id)
      unless SwiftProxy.find(proxy_id).blank?
        begin
          result = session(gateway_id) do |session|
            session.exec!("status-proxy #{SwiftProxy.find(proxy_id).realm}")
          end

          JSON.parse(result) rescue { 'return' => 'failed'}
        rescue
          { 'return' => 'failed', 'status' => 'gateway-unreachable' }
        end
      else
        { 'return' => 'not_activated' }
      end
    end

    def status_proxy_all(gateway_id, proxy_ids)
      return { 'return' => 'not_activated' } if (gateway = SwiftGateway.find_by(id: gateway_id)).nil?
      return { 'return' => 'failed' } if SwiftProxy.where(id: proxy_ids).none?

      args = default_ssh_args.dup.merge(
        port:     (gateway.sic_port || 22),
        key_data: [gateway.sic_ssh_private_key]
      )

      queue = Queue.new(SwiftProxy.where(id: proxy_ids))
      result = {}

      threads = (queue.size < 10 ? queue.size : 10).times.map do
        Thread.new do
          while (proxy = (queue.pop(true) rescue nil))
            begin
              Net::SSH.start(gateway.sic_host, '#chef-remote#', args) do |session|
                result[proxy.id] = JSON.parse(session.exec!("status-proxy #{proxy.realm}"))
              rescue StandardError
                { 'return' => 'failed' }
              end
            rescue StandardError
              result[proxy.id] = { 'return' => 'failed', 'status' => 'gateway-unreachable' }
            end
          end
        end
      end

      threads.map(&:join)

      result
    end

    def session(gateway_id, &block)
      debug = false

      if gateway = SwiftGateway.find(gateway_id)
        unless gateway.sic_host.blank?
          if SwiftPartition.find(gateway.partition_id)
            start_args = {
                config:                     false,
                use_agent:                  false,
                non_interactive:            true,
                keys_only:                  true,
                port:                       (gateway.sic_port || 22),
                timeout:                    3,
                auth_methods:               %w(publickey),
                keys:                       [],
                key_data:                   [gateway.sic_ssh_private_key],
                number_of_password_prompts: 0
            }

            if debug
              logger       = Logger.new(STDOUT)
              logger.level = Logger::DEBUG
              start_args.merge!({ verbose: Logger::DEBUG, logger: logger })
            end

            Net::SSH.start(gateway.sic_host, '#chef-remote#', start_args) do |session|
              yield session
            end
          end
        end
      end
    end

    private

    def default_ssh_args
      {
        config:                     false,
        use_agent:                  false,
        non_interactive:            true,
        keys_only:                  true,
        timeout:                    3,
        auth_methods:               %w[publickey],
        keys:                       [],
        number_of_password_prompts: 0
      }
    end

    def susshi_uniqid_to_hash(susshi_uniqid)
      # Format is 20251015-044155-0001-26461
      keys = %i[date time identifier pid]
      keys.zip(susshi_uniqid.split("-")).to_h
    end
  end
end
