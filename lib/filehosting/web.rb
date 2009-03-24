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

# Most of the content of this file moved to ‘web-full.rb‘. It is only
# loaded in case it is needed. So we can load already cached files
# much faster.

require "pathname"

module FileHosting

	class Web

		CacheDir= Pathname.new("/tmp/filehosting-cache")
		StaticDir= Pathname.new("web")
		
		attr_accessor :datasource

		def initialize(datasource= nil)
			@datasource= datasource
			CacheDir.mkdir unless CacheDir.directory?
		end

		# Returns an IO object where the requested page can be
		# read. Returns nil if the page can not be viewed.
		def get_page(path, args)
			file= StaticDir+path
			return nil unless file.cleanpath == file
			if file.file?
				return File.new(file)
			end
			file= CacheDir+(path.dir_encode+"?"+args.dir_encode)
			if file.file?
				File.new(file)
			else
				yield if block_given?
				require "filehosting/web-full"
				get_page(path, args)
			end
		end

		def self.parse_get(query_string)
			query_string=~ /^/
			res= Hash.new
			while $'=~ /^([^&=]+)=([^&]+)(&|$)/
				key= $1
				value= $2
				res[key.http_decode]= value.http_decode
			end
			res
		end

	end

end

class String

	def dir_encode
		self.gsub("%", "%%").gsub("/", "%#").gsub(".", "%.")
	end

	def http_decode
		res= ""
		self=~ /^/
		rem= $'
		while $'=~ /%([A-Za-z0-9]{2})/
			rem= $'
			res+= $`
			res<< $1.to_i(16)
		end
		res+rem
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
