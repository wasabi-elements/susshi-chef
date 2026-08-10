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

module Api::V1
  class ReportsController < ApiApplicationController

    respond_to :json, :xml

    before_action :validate_report_params, only: [:sessions]

    #
    # Format of reports is JSON
    # JSON(@params.reports) --> [{report1}, {report2}, ...]
    # Each {report} --> {"20170827-113319-0001-20801" => {"cmd_reject"=>0, session_start"=>1503826403, "session_state"=>"finished", ...}
    # {report}.keys.first => "20170827-113319-0001-20801" (uniq_id)
    # {report}.values.first => {"cmd_reject"=>0, session_start"=>1503826403, "session_state"=>"finished", ...} (values)
    #

    def sessions

      while true # Just to break out in case of error

        part_id = SwiftGateway.where(identifier: @params.susshid_id).pluck(:partition_id).first
        break unless part_id

        JSON(@params.reports).each do |record|
          uniq_id = record.keys.first
          rep     = record.values.first

          # Skip denied records
          next if rep['session_state'] == 'denied'
          rep['session_start'] = Time.at(rep['session_start']) unless rep['session_start'].blank?

          # Extract client auth set and update cache flag
          ca_set_id = rep.delete('ca_set_id')

          import_keys = rep.keys
          import_keys << 'crash'

          report = SessionReport.new(susshi_uniqid: uniq_id, partition_id: part_id, crash: false)
          report.assign_attributes(rep)

          #-- Do some things only on new reports

          if report.session_state == 'new'

            Chef::SwiftTracker.skip = true

            #- 1. Update usage statistics - User

            unless report.susshi_user.blank?
              unless (user = SusshiUserLogin.where(name: report.susshi_user, partition_id: part_id).first).blank?
                user.increment(:use_count)
                user.first_use_at ||= Time.now
                user.last_use_at = Time.now
                user.save
              end
            end

            #- 2. Update usage statistics - Access & Bastion Rules

            unless report.rule_id.blank? or report.rule_id < 1
              case report.operation_mode
                when 0    #--- Gateway mode
                  unless (access = Access.where(id: report.rule_id, partition_id: part_id).first).blank?
                    access.increment(:use_count)
                    access.first_use_at ||= Time.now
                    access.last_use_at = Time.now
                    access.save
                  end
                when 1    #--- Bastion-Mode
                  unless (bastion = Bastion.where(id: report.rule_id, partition_id: part_id).first).blank?
                    bastion.increment(:use_count)
                    bastion.first_use_at ||= Time.now
                    bastion.last_use_at = Time.now
                    bastion.save
                  end
              end
            end

            #- 3. Update IP Cache

            if user and (ca_set_id || 0) > 0
              unless (cas = SwiftClientAuthSet.where(partition_id: part_id, id: ca_set_id).first).blank?
                if cas.cache_enabled? && cas.operational?
                  SwiftIpCaching.lookup(
                    create:               true,
                    refresh:              cas.cache_refresh,
                    source_ip:            rep['client_ip'],
                    swift_susshi_user_id: user.id,
                    client_auth_set_id:   cas.id,
                    cache_idle_time:      cas.cache_idle_time,
                    max_cache_time:       cas.max_cache_time,
                    whitelist:            cas.cache_whitelist
                  )
                end
              end
            end

            Chef::SwiftTracker.skip = false
          end

          if report.session_state == 'finished'
            report.session_end = report.session_start + report.session_time
            import_keys << 'session_end'

            # Cleanup OIDC tickets
            SwiftAuthTicket.remove_susshi_uniqid(uniq_id)
          end

          # Import Record into DB
          SessionReport.import [report], on_duplicate_key_update: { conflict_target: [:susshi_uniqid], columns: import_keys.uniq }
        end

        head :ok, status: 200
        return

      end

      respond_with_error('Something went wrong', 500)

    end

    private

    def validate_report_params
      @params = Api::V1::Validate::Reports.new(params)
      validate_params(@params)
    end

    def respond_with_error(text, code)
      respond_to do |format|
        format.json { render :json => { :error => text }, :status => code }
      end
    end

  end
end