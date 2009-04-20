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

require "pathname"

# Most of the content of this file moved to ‘web-full.rb‘. It is only
# loaded in case it is needed. So we can load already cached files
# much faster.

module FileHosting

	class Web

		attr_accessor :config

		StaticDir= Pathname.new("web")

		def initialize(config)
			@config= config
		end

		# Returns a String, an IO, or an Array of String's and
		# IO's. The String holds the data, from an IO can the
		# data be read. And in case of an Array all String's
		# and IO's have to be parsed to get the full data.
		def get_page(path, args, input= nil, type= nil)
			unless (unless input
				file= StaticDir+path
				return nil unless file.cleanpath == file
				if file.file?
					return File.new(file)
				end
				file= Pathname.new(@config[:storage_args]) + "cache" + "data" + ("web/anonymous/" + path.dir_encode + "?" + args.dir_encode).dir_encode
				if file.file?
					return File.new(file)
				end
				nil
			end)
				yield if block_given?
				require "filehosting/web"
				get_page(path, args, input, type)
			end
		end

		def self.parse_get(query_string)
			query_string=~ /^/
			res= Hash.new
			while $'=~ /^([^&=]+)=([^&]*)(&|$)/
				key= $1
				value= $2
				res[key.uri_decode]= value.uri_decode
			end
			res
		end

	end

end

class String

	def uri_decode
		res= ""
		self.gsub("+", " ")=~ /^/
		rem= $'
		while $'=~ /%([A-Za-z0-9]{2})/
			rem= $'
			res+= $`
			res<< $1.to_i(16)
		end
		res+rem
	end

	def dir_encode
		self.gsub("%", "%%").gsub("/", "%#").gsub(".", "%.")
	end

end

class Hash

	def dir_encode
		keys.sort.collect do |key|
			key.to_s.dir_encode.gsub("=", "%=").gsub("&", "&%") +
			"=" +
			self[key].to_s.dir_encode.gsub("=", "%=").gsub("&", "&%")
		end.join("&")
	end

end

