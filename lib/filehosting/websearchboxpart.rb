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

require "filehosting/webpart"
require "filehosting/html"
require "filehosting/fileinfo"
require "filehosting/string"

require "filehosting/uuid"

module FileHosting

	# Displays an input to search for tags.
	class WebSearchBoxPart < WebPart

		# The block is used to build url's. The block is
		# called everytime a url is build it's arguments
		# are an array of tags. The block should return an
		# url.
		def initialize(config, tags, rule= nil, full=false, &block)
			@url_builder= block
			super(config) do
				tags= config[:default_search] if tags.empty?

				HTML.use_template("searchboxpart.eruby", binding)
			end
		end

		def build_url(tags, rule=nil)
			@url_builder.call(tags, rule)
		end

		def cachable
			false
		end

	end

end

