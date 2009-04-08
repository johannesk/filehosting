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

		attr_reader :location

		def initialize(config, location, *tags)
			super(config)
			@location= location
			@header["Location"]= webroot.to_s+location
			@tags= tags.flatten
		end

		def status
			301
		end

		def body
			""
		end

		def size
			0
		end

	end

end

