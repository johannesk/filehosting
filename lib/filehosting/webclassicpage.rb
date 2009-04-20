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

		def initialize(config, *tags)
			@config= config
			tags.flatten!
			title= "/"
			title+= tags.join("/") unless tags.empty?
			if tags.empty?
				tags= config.datasource.tags.sort
				dep= ["tags"]
				body= HTML.use_template("classic_new.eruby", binding)
			else
				search_result= config.datasource.search_tags(tags)
				dep= tags.collect { |tag| "tags/#{tag}" } + search_result.collect { |file| "files/#{file.uuid.to_s}" }
				deb+= ["rules/search", "rules/search_filter", "rules/file", "rules/file_info"]
				body= HTML.use_template("classic.eruby", binding)
			end
			super(config, title, body, "classic.css", "sortable.js")
			@tags+= dep
		end

	end

end
