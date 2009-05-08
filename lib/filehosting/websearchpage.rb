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

		def initialize(config, search=[], rules= nil)
			@config= config
			search.flatten!
			title= "search"
			title+= ": #{search.join(", ")}" unless search.empty?
			error= nil
			if search.empty?
				tags= config.datasource.real_tags.sort
				search= config[:default_search]
				body= HTML.use_template("search_new.eruby", binding)
			else
				begin
					rule= nil
					if rules
						rule= FileHosting::Rule.new(true)
						rules.each do |r|
							next if r.strip.empty?
							rule.add_raw(r)
						end
					end
					search_result= config.datasource.search_tags(search, rule)
					body= HTML.use_template("search.eruby", binding)
				rescue RuleError => e
					raise e unless e.rule == rule
					error= e.to_s
					tags= config.datasource.tags.sort
					body= HTML.use_template("search_new.eruby", binding)
				end
			end
			super(config, title, body, "search.css")
		end

	end

end
