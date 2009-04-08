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
require "filehosting/nosuchfileerror"


module FileHosting

	# The remove page
	class WebRemovedPage < WebUUIDPage

		def initialize(config, uuid)
			super(config, uuid, "remove.css") do |uuid|
				begin
					config.datasource.remove_file(uuid)
					@status= 201
				rescue NoSuchFileError
					@status= 404
					return
				end
				["removed: #{uuid.to_s}", HTML.use_template("removed.eruby", binding)]
			end
		end

		def cachable
			false
		end

	end

end
