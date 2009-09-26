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
require "filehosting/rule"
require "filehosting/html"
require "filehosting/ruleerror"

module FileHosting

	# The search page
	class WebSearchPage < WebDefaultPage

		def initialize(config, search=[], rule= nil)
			super(config) do
				search.flatten!
				title= "search"
				error= nil
				if search.empty?
					tags= config.datasource.tags.sort
					[title, HTML.use_template("search_new.eruby", binding)]
				else
					title+= ": #{search.join(", ")}"
					begin
						# do the search
						search_result= config.datasource.search_tags(search, rule)

						[title, HTML.use_template("search.eruby", binding)]
					rescue RuleError => e
						raise e unless e.rule == rule
						error= e.to_s
						tags= config.datasource.tags.sort
						[title, HTML.use_template("search_new.eruby", binding)]
					end
				end
			end
		end

		def self.url(tags=[], rule= nil)
			tags= [tags].flatten
			rules= if rule
				"&rules="+
				rule.conditions.collect { |a, test, b| "#{a} #{test} #{b}" }.join(" \n ").uri_encode
			else
				""
			end
			"/search?tags=" + tags.join(" ").uri_encode+rules
		end

	end

end
