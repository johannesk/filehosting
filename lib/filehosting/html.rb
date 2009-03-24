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
			page("error", use_template("error.eruby", binding), "error.css")
		end

		def self.use_template(file, bind)
			tfile= Pathname.new("templates") + file
			template= ERB.new(tfile.read, nil, "%")
			template.result(bind)
		end

		def self.http_decode(string)
		end

	end

end

class Object

	def to_html
		if respond_to?(:to_text)
			to_text
		else
			to_s
		end.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
	end

end

module FileHosting

	class FileInfo

		def to_html
			fileinfo= self
			HTML.use_template("fileinfo.eruby", binding)
		end

	end

	class HistoryEvent

		def to_html
			event= self
			HTML.use_template("historyevent.eruby", binding)
		end

	end

end
