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

require "filehosting/webrpc"
require "filehosting/json"

module FileHosting

	# This is a variant of the WepRPC which encodes it's responses
	# as json.
	class WebJSON < WebRPC

		# args are the url folders. io is the http body as an
		# IO object.
		# FIXME methods which need FileInfo Objects or IO as
		# input can not be called.
		def initialize(config, args, io)
			# We do handle our errors by ourself
			@error_handled= true

			super(config, args, "application/json") do |content|
				content.to_json
			end
		end

	end

end
