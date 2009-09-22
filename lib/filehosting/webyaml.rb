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

module FileHosting

	# This is a variant of the WepRPC which encodes it's responses
	# as yaml.
	class WebYAML < WebRPC

		# args are the url folders. io is the http body as an
		# IO object.
		def initialize(config, args, io)
			# We do handle our errors by ourself
			@error_handled= true

			# parse the args from the io
			begin
				YAML.each_document(io) do |doc|
					# Caching does not take the
					# http body in account. FIXME
					@cachable= false
					args<< doc
				end
			rescue InternalDataCorruptionError
			# if it can not be parsed by yaml
				@status= 400
				@body= "invalid request body"
				@cachable= false
				return
			end

			super(config, args, "text/x-yaml") do |content|
				content.to_yaml
			end
		end

	end

end
