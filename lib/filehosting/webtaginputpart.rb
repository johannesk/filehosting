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
require "filehosting/string"

module FileHosting

	# Displays an input for tags
	class WebTagInputPart < WebPart

		def initialize(config, name, tags= nil, size=nil)
			super(config) do
				tags= config[:default_search] unless tags

				HTML.use_template("taginputpart.eruby", binding)
			end
		end

		def cachable
			false
		end

	end

end

