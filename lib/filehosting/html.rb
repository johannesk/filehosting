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

require "erb"
require "pathname"

module FileHosting

	# Create a webpage
	class HTML

		def self.page(title, body, styles=[])
			use_template("page.eruby", binding)
		end

		def self.error_page(error)
			page("error", error.to_html)
		end

		def self.use_template(file, bind)
			tfile= Pathname.new("templates") + file
			template= ERB.new(tfile.read, nil, "%")
			template.result(bind)
		end

		def self.parse_get(query_string)
			query_string=~ /^/
			res= Hash.new
			while $'=~ /^([^&=]+)=([^&]+)(&|$)/
				res[$1]= $2
			end
			res
		end

	end

end

class Object

	def to_html
		to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
	end

end

module FileHosting

	class FileInfo

		def to_html
			fileinfo= self
			HTML.use_template("fileinfo.eruby", binding)
		end

	end

end
