#
# Author:: Johannes Krude
# Copyright:: (c) Johannes Krude 2009
# License:: AGPL3
#
#--
# This file is part of filehosting.
#
# filehosting is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# filehosting is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with filehosting.  If not, see <http://www.gnu.org/licenses/>.
#++
#

require "filehosting/error"

module FileHosting

	# This error indicates something was not in the way it was
	# supposed to be.
	class VersionMismatchError < Error

		# Which component expected another version
		attr_reader :component
		# The expected version
		attr_reader :expected
		# The actual version
		attr_reader :actual

		def initialize(component, expected, actual)
			@component= component
			@expected= expected
			@actual= actual
		end

		def to_s
			"'#{component}' version should be '#{expected}' but is '#{actual}'"
		end

	end

end

