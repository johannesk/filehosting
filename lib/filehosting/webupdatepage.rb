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

require "filehosting/webfileinfopage"
require "filehosting/html"


module FileHosting

	# The update page
	class WebUpdatePage < WebFileInfoPage

		def initialize(config, uuid, values= nil)
			super(config, uuid, "update.css") do |fileinfo|
				updated= false
				wrong_filename= false
				wrong_tags= false
				wrong_source= false
				if values
					@cachable= false
					fileinfo.filename= values["filename"] if values["filename"]
					fileinfo.tags= values["tags"].split("+") if values["tags"]
					fileinfo.source= values["source"] if values["source"]
					if fileinfo.filename.empty?
						wrong_filename= true
					end
					if fileinfo.tags.empty?
						wrong_tags= true
					end
					if fileinfo.source.empty?
						wrong_source= true
					end
					unless wrong_filename or wrong_tags or wrong_source
						config.datasource.update_fileinfo(fileinfo)
						updated= true
						@status= 201
					end
				end
				["update: #{fileinfo.uuid.to_s}", HTML.use_template("update.eruby", binding)]
			end
		end

	end

end
