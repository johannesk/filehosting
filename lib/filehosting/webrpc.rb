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
require "filehosting/typifieing"

require "filehosting/uuid"

module FileHosting

	# This class allows rpc calls to config.datasource over the
	# web. Non FileHosting objects are transmitted as a folder in
	# the url. FileHosting objects must be transmitted in the http
	# body. They must be decoded before calling WebRPC.new.
	# The return value of the RPC must be encoded by the block
	# given to initalize.
	class WebRPC < WebPage

		# args are the url folders and decoded FileHosting
		# objects.
		# FIXME add_file and update_filedata cannot be called
		def initialize(config, args, contenttype, &block)
			super(config)
			@header["Content-Type"]= contenttype
			# We do handle our errors by ourself
			@error_handled= true
			# We are cachable unless the method called has
			# side effects
			@cachable= true
			if args.empty?
				@status= 404
				@body= "no method given"
				return
			end
			method= args.shift.to_sym
			# We are not cachable with side effects
			@cachable= false if config.datasource.class.sideeffect_announced?(method)
			unless config.datasource.class.method_announced?(method)
			# ensure only available methods can be called
				@status= 404
				@body= "no such method"
				return
			end

			args= Typifieing::parse_args(config.datasource.class.method_args(method), args)
			unless args
				@status= 400
				@body= "invalid args"
				return
			end
			@body= yield config.datasource.send(method, *args)
		end

	end

end

