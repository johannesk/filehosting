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

require "filehosting/webuuidpage"
require "filehosting/html"


module FileHosting

	# The parent of all fileinfo WebPages
	class WebFileInfoPage < WebUUIDPage

		attr_reader :fileinfo

		def initialize(config, uuid, *includes)
			includes= ["fileinfo.css"] unless block_given?
			super(config, uuid, *includes) do |uuid|
				@tags= ["files/#{uuid.to_s}"]
				begin
					@fileinfo= config.datasource.fileinfo(uuid)
				rescue NoSuchFileError
					@status= 404
					next ["", ""]
				end
				@tags+= ["rules/file", "rules/file_info"]
				if block_given?
					yield @fileinfo
				else
					[uuid.to_s, HTML.use_template("fileinfo.eruby", binding)]
				end
			end
		end

	end

end
