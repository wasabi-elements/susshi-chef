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

module Errors::Api

  class Any < StandardError
    def message
      'General error. Please contact your administrator.'
    end
  end

  class ApiAuthFailed < Any
    def message
      'API Authentication failed.'
    end
  end

  class CreationFailed < Any
    def message
      'Object creation failed. Probably object already exists.'
    end
  end

  class UpdateFailed < Any
    def message
      'Object update failed. Maybe parameters are missing or wrong?'
    end
  end

  class ParametersAmbiguous < Any
    def message
      'Parameters are ambiguous.'
    end
  end

  class ParametersMissing < Any
    def message
      'Parameters are missing.'
    end
  end

  class SystemInternalObject < Any
    def message
      'The object is system internal and can not be changed.'
    end
  end

  class MemberReferencesNotFound < Any
    attr_reader :msg

    def initialize(msg)
      @msg = msg
      super(msg)
    end

    def message
      msg ? msg : 'The membership references could not be resolved completely. Please ensure, that all members exist.'
    end
  end

  class ObjectNotFound < Any
    def message
      'Not found.'
    end
  end

  class TargetNotFound < Any
    def message
      'Target not found.'
    end
  end

  class TypeUnknown < Any
    def message
      'Type is unknown / not included in list.'
    end
  end

  class ProfileNotFound < Any
    def message
      'Profile not found.'
    end
  end

  class NoGatewayFound < Any
    def message
      'No Gateway found.'
    end
  end

  class HostKeyScanParameter < Any
    def message
      'Host key scan parameter is wrong.'
    end
  end

  class HostKeyScanFailed < Any
    def message
      'Host key scan failed.'
    end
  end

end
