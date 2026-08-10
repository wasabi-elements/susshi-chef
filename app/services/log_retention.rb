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

class LogRetention

  class << self

    def _system_event_choices
      [
          ['1 Day', 1.day],
          ['2 Days', 2.days],
          ['3 Days', 3.days],
          ['4 Days', 4.days],
          ['5 Days', 5.days],
          ['6 Days', 6.days],
          ['1 Week', 1.week],
          ['2 Weeks', 2.weeks],
          ['3 Weeks', 3.weeks],
          ['1 Month', 1.month],
          ['2 Months', 2.months],
          ['3 Months', 3.months]
      ]
    end

    def system_event_choices
      _system_event_choices.map{|x| [x.first, x.second.to_i/86400]}
    end

    def _session_report_choices
      [
          ['1 Week', 1.week],
          ['2 Weeks', 2.weeks],
          ['3 Weeks', 3.weeks],
          ['1 Month', 1.month],
          ['2 Months', 2.months],
          ['3 Months', 3.months],
          ['4 Months', 4.months],
          ['5 Months', 5.months],
          ['6 Months', 6.months],
          ['9 Months', 9.months],
          ['1 Year', 1.year],
          ['2 Years', 2.years],
          ['3 Years', 3.years],
      ]
    end

    def session_report_choices
      _session_report_choices.map{|x| [x.first, x.second.to_i/86400]}
    end

    def purge_session_reports
      p = Preference.first
      return if p.session_report_retention_days.blank?
      SessionReport.where('updated_at < ?', DateTime.now - p.session_report_retention_days.days).delete_all
    end

    def purge_system_events
      p = Preference.first
      return if p.syslog_retention_days.blank?
      SystemEvent.where('devicereportedtime < ?', DateTime.now - p.syslog_retention_days.days).delete_all
    end

  end

end