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

	# a page only to redirect to another page
	class WebRedirect < WebPage

		# the location where to redirect
		attr_reader :location
		# whether the redirect needs to be done by the browser
		attr_reader :external

		def initialize(config, location, external= false)
			super(config)
			@status= 301
			@location= location
			@header["Location"]= webroot.to_s+location
			@error_handled= external
		end

		def body
			""
		end

		def size
			0
		end

	end

end

