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

class SessionReport < ApplicationRecord

  #-- Datatypes

  # upsert_keys [:susshi_uniqid]

  #-- Associations
  belongs_to :partition

  #-- Scopes

  #-- Validations

  #-- Public attributes

  #-- Class Methods

  class << self

    def state_collection
      [ ['Active Sessions', 'active,new' ], ['Finished Sessions', 'finished'], ['Denied Sessions', 'denied'], ['Failed Sessions', 'failed'] ]
    end

    def operation_mode_collection
      [ ['Gateway', 0], ['Bastion', 1] ]
    end

    def operation_modes_text
      { 0 => 'Gateway', 1 => 'Bastion', 2 => 'Shell', 3 => 'Chef-Remote' }
    end

    def operation_modes_sym
      { 0 =>  :gateway, 1 => :bastion, 2 => :shell, 3 => :chef_remote }
    end

    def process_crashed_reports(partition_id)
      period = SwiftPartition.find_by_partition_id(partition_id).config['ReportPeriod'] rescue nil
      period ||= PartitionSetting.find_by_partition_id(partition_id).ReportPeriod || 900
      SessionReport.where("updated_at < ?", (Time.now - period - 1)).where(session_state: %w(new active)).each do |report|
        report.update_columns(crash: true, session_state: 'finished')
      end
    end

  end

  #-- Instance Methods

  def icon
    case operation_mode
    when 0
      'fa-gem'
    when 1
      'fa-chess-rook'
    when 2
      'fa-terminal'
    else
      'fa-question-circle'
    end
  end

  def get_client_socket
    if client_ip =~ /:[0-9]+/
      "[#{client_ip}]:#{client_port}"
    else
      "#{client_ip}:#{client_port}"
    end
  end

  def get_target
    if operation_mode == 1
      "<span class='target_info'><span class='target'>bastion</span><span class='proxy'>#{proxy_realm.blank? ? '':'@'+proxy_realm}</span></span></span>"
    else
      return 'suSSHi Shell' if target_ip.blank? && target_host.blank?
      ip = if target_port != 22
             if target_ip =~ /:[0-9]+/
               "[#{target_ip}]:#{target_port}"
             else
               "#{target_ip}:#{target_port}"
             end
           else
             target_ip
           end
      host = target_port != 22 ? "<span class='target'>#{target_host}</span>:#{target_port}" : "<span class='target'>#{target_host}</span>"
      "<span class='target_info'><span class='target'>#{target_user}@</span>#{host}<span class='proxy'>#{proxy_realm.blank? ? '':'@'+proxy_realm}</span> [ <span class='ip'>#{ip.blank? ? 'unresolved' : ip }</span> ]</span>"
    end
  end

  def operation_mode_text
    SessionReport.operation_modes_text[self.operation_mode]
  end

  def operation_mode_sym
    SessionReport.operation_modes_sym[self.operation_mode]
  end

  #-- Helper

  def rule_id_formatted
    '%05d' % (self.rule_id || 0)
  end

end
