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

require "filehosting/webpage"

module FileHosting

	# a page to make the browser submit username and password
	class Web401Page < WebPage

		attr_reader :auth_reason

		def initialize(config, reason)
			super(config)
			@auth_reason= reason
			@header["WWW-Authenticate"]= "Basic realm=\"#{reason}\""
		end

		def status
			401
		end

		def body
			""
		end

		def size
			0
		end

		def cachable
			true
		end

	end

end

