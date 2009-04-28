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

require "filehosting/webdefaultpage"
require "filehosting/html"
require "filehosting/fileinfo"
require "filehosting/time"

module FileHosting

	# The add page
	class WebAddPage < WebDefaultPage

		def initialize(config, values= nil)
			@config= config
			fileinfo= FileInfo.new
			wrong_filename= false
			wrong_tags= false
			wrong_date= false
			wrong_source= false
			wrong_filedata= false
			wrong_groups= false
			if values
				@cachable= false
				fileinfo.filename= values["filename"]
				fileinfo.tags= values["tags"].split(" ") if values["tags"]
				begin
					fileinfo.user_date= Time.from_form(values["date"]) if values["date"]
				rescue ArgumentError
					wrong_date= true
				end
				fileinfo.source= values["source"]
				fileinfo.groups= values["groups"].split(" ") if values["groups"]
				if fileinfo.filename.nil? or fileinfo.filename.empty?
					wrong_filename= true
				end
				if fileinfo.tags.nil? or fileinfo.tags.empty?
					wrong_tags= true
				end
				if fileinfo.source.nil?
					fileinfo.source= ""
				end
				unless File === values["filedata"]
					wrong_filedata= true
				else
					file= Pathname.new(values["filedata"].path)
					if file.size == 0
						wrong_filedata= true
					end
				end
				unless wrong_filename or wrong_tags or wrong_source or wrong_filedata
					config.datasource.add_file(fileinfo, file)
					@status= 201
					super(config, "added file", HTML.use_template("fileinfo.eruby", binding), "fileinfo.css")
					return
				end
			end
			super(config, "add file", HTML.use_template("add.eruby", binding), "add.css")
		end

	end

end
