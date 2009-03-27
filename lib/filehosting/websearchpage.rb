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

	# The search page
	class WebSearchPage < WebDefaultPage

		def initialize(config, *tags)
			@config= config
			tags.flatten!
			title= "search"
			title+= ": #{tags.join(", ")}" unless tags.empty?
			if tags.empty?
				tags= config.datasource.tags.sort
				dep= ["tags"]
				body= HTML.use_template("search_new.eruby", binding)
			else
				search_result= config.datasource.search_tags(tags)
				dep= tags.collect { |tag| "tags/#{tag}" } + search_result.collect { |file| "files/#{file.uuid.to_s}" }
				body= HTML.use_template("search.eruby", binding)
			end
			super(config, title, body, "search.css")
			@tags+= dep
		end

	end

end
