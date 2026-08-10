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

class SystemEvent < ApplicationRecord
  self.table_name = 'systemevents'

  LOG_LEVEL_CLASSES = %w[Emergency Alert Critical Error Warning Notice Info Debug]
  LOG_LEVEL_CSS_CLASSES = %w[danger danger danger warning warning primary primary info]

  def log_level_class
    if [LOG_LEVEL_CLASSES[self.priority], LOG_LEVEL_CSS_CLASSES[self.priority]].all?
      [LOG_LEVEL_CLASSES[self.priority][0], LOG_LEVEL_CSS_CLASSES[self.priority]]
    end
  end

  class << self
    def log_level(log_level_class)
      LOG_LEVEL_CLASSES.find_index { |item| item.to_s.downcase == log_level_class.to_s.downcase }
    end

    def log_level_classes
      LOG_LEVEL_CLASSES.each_with_index.map { |value, index| [value, index] }
    end

    def generic_event(message, log_level: :info)
      unless (priority = SystemEvent.log_level log_level).nil?
        SystemEvent.create message: message, devicereportedtime: Time.now, priority: priority
      end
    end
  end

end
