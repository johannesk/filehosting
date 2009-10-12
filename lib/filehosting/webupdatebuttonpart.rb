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

require "filehosting/webbuttonpart"
require "filehosting/webupdatepage"

module FileHosting

	class WebUpdateButtonPart < WebButtonPart

		def initialize(config, fileinfo)
			super(config, "update/#{fileinfo.uuid}") do
				[!datasource.pretend(:update_fileinfo, fileinfo) || !datasource.pretend(:update_filedata, fileinfo), WebUpdatePage.url(fileinfo), "update", "update"]
			end
		end

	end

end

