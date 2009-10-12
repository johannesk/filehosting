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

require "io2io"
require "time"
autoload :Base64, "base64"

module FileHosting

	# This is a ruby interface to the cgi interface
	class CGI

		# the requested path
		attr_reader :path

		# the query string (a=b&c=d...)
		attr_reader :query

		# the transmitted cookies
		attr_reader :cookies

		# the username if it exists
		attr_reader :username

		# the password if it exists
		attr_reader :password

		# the client has a version from this time
		attr_reader :cache_time

		# the content type of the body
		attr_reader :content_type

		# the length of the body
		attr_reader :content_length

		# the body as IO if it exists
		attr_reader :body

		# whether the request is invalid
		attr_reader :invalid

		def initialize
			@invalid= false

			# parse path
			@path= (ENV["PATH_INFO"] || "").sub(/^\//, "")

			# parse query-string
			@query= ENV["QUERY_STRING"]

			# parse cookies
			@cookies= read_cookies(ENV["HTTP_COOKIE"] || "")

			# parse auth
			@username, @password= if auth= ENV["HTTP_AUTHORIZATION"]
				begin
					read_auth(auth)
				rescue ArgumentError
					@invalid= true
					[nil, nil]
				end
			end

			# parse if-not-modified-since
			@cache_time= if time= ENV["HTTP_IF_NOT_MODIFIED_SINCE"]
				begin
					Time.httpdate(time)
				rescue ArgumentError
					@invalid= true
					nil
				end
			end

			# parse content stuff
			@content_length= (ENV["CONTENT_LENGTH"] || 0).to_i
			if @content_length > 0
				@body= STDIN
				@content_type= ENV["CONTENT_TYPE"]
				@invalid= true unless @content_type
			else
				@body= nil
			end
		end

		# parses cookies given from ENV["HTTP_COOKIE"] and
		# returns them as hash
		def read_cookies(str)
			res= Hash.new
			str.split(/; */).each do |cookie|
				if cookie=~ /^([\w-]+) *= *([\w-]+|"[^"]+")$/
					res[$1]= $2.gsub(/^"|"$/, "")
				end
			end
			res
		end

		# Parses the Basic auth string. Returns
		# [username, password].
		def read_auth(str)
			# we do only basic auth
			if str=~ /^Basic\s+/ and Base64.decode64($')=~ /^([^:]*):(.*?)$/
				return $1, $2
			else
				raise ArgumentError.new("'#{str}' is not a basic auth string")
			end
		end

		# Transmits an answer
		def out(io)
			[io].flatten.each do |out|
				case out
				when String
					STDOUT.print out
				when IO
					IO2IO.do(out, STDOUT)
				else
					raise NotImplementedError
				end
			end
		end

		# Transmits an answer with a newline
		def puts(io= [])
			out([io, "\n"])
		end

	end

end
