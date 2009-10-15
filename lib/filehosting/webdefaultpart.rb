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

require "erb"

module FileHosting

	# the default webpage part
	class WebDefaultPart < WebPart

		def initialize(config, title, body, includes)
			super(config, "default") do
				HTML.use_template("default.eruby", binding)
			end
			includes= (webdependencies + includes).uniq
			@body= ERB.new(@body, nil, "%").result(binding)
		end

	end

end

