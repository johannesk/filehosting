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

require "filehosting/webdefaultpage"
require "filehosting/html"

module FileHosting

	# The classic page
	class WebClassicPage < WebDefaultPage

		def initialize(config, path, tags= nil)
			super(config) do
				tags= [tags].flatten if tags
				path= [path].flatten
				title= "/"
				title+= path.join("/") unless path.empty?
				if path.empty?
					dirs= config.datasource.real_tags.sort
					dirs= dirs.find_all { |x| tags.include?(x) } if tags
					[title, HTML.use_template("classic_new.eruby", binding)]
				else
					search_result= config.datasource.search_tags(path)
					search_result.sort { |a,b| b.user_time <=> a.user_time }
					[title, HTML.use_template("classic.eruby", binding)]
				end
			end
		end

		def self.url(path, tags, encode= false)
			path= path.join("/")
			path= "/" + path unless path.empty?
			path= path.uri_encode if encode
			path + case
			when !tags
				""
			when tags.size == 0
				""
			else
				t= tags.join(" ")
				t= t.uri_encode if encode
				"?tags=" + t
			end
		end

	end

end
