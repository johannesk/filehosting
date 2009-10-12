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

require "filehosting/webredirect"

require "uri"

module FileHosting

	# The login Page has a status of 401 if the user is
	# 'anonymous'.
	class WebLogin < WebRedirect

		attr_reader :auth_reason

		def initialize(config)
			@config= config
			if @config.datasource.current_user.username == "anonymous"
				@status= 401
				@auth_reason= "login"
				@error_handled= false
			else
				user= @config.datasource.current_user
				set_cookie("logged-in", "true")
				path= if referer= ENV["HTTP_REFERER"]
					begin
						referer= URI.parse(referer)
						base= URI.parse(config[:webroot])
					rescue URI::InvalidURIError
						"/"
					end
					res= referer-base
					unless res.scheme or res.userinfo or res.host or res.port or res.registry or res.path=~ /^\.\./
						res.path + (res.query ? "?" + res.query : "")
					else
					# not from the this filehosting site
						"/"
					end
				else
					"/"
				end
				super(config, path, true)
			end
		end

	end

end
