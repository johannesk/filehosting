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

require "uuidtools"

module FileHosting

	# the fileinfo part
	class WebFileInfoPart < WebPart

		def initialize(config, fileinfo)
			uuid= case fileinfo
			when UUID
				fileinfo
			when FileInfo
				fileinfo.uuid
			else
				raise NotImplementedError
			end
			super(config, "fileinfo/#{uuid}") do
				fileinfo= block.call unless FileInfo === fileinfo
				[HTML.use_template("fileinfo.eruby", binding), ["files/#{fileinfo.uuid}", "rules/file", "rules/file_info"]]
			end
		end

	end

end

