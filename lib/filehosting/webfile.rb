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
require "filehosting/nosuchfileerror"

module FileHosting

	# The sourcecode webpage
	class WebFile < WebPage

		attr_reader :uuid

		def initialize(config, uuid, date)
			super(config)
			begin
				@uuid= UUID.parse(uuid)
			rescue ArgumentError
				@status= 404
				@cachable= true
				return
			end
			begin
				fileinfo= @config.datasource.fileinfo(@uuid)
			rescue NoSuchFileError
				@status= 404
				@cachable= true
				return
			end
			if date and fileinfo.data_time == date
				@status= 304
			end
			@header["Content-Type"]= fileinfo.mimetype
			@header["Content-Disposition"]= "attachment;filename=#{fileinfo.filename}"
			@size= fileinfo.size
		end

		def body
			@config.datasource.filedata_io(@uuid)
		end

	end

end

