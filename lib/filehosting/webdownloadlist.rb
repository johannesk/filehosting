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

require "filehosting/webpage"
require "filehosting/rule"
require "filehosting/ruleerror"
require "filehosting/webfile"

module FileHosting

	# The download list
	class WebDownLoadList < WebPage

		def initialize(config, tags=[], rules= nil)
			@config= config
			@header= {"Content-Type" => "text/plain; charset=utf-8"}
			@status= 200
			@cachable= true
			tags.flatten!
			begin
				rule= nil
				if rules
					rule= FileHosting::Rule.new(true)
					rules.each do |r|
						next if r.strip.empty?
						rule.add_raw(r)
					end
				end
				files= if tags.empty?
					config.datasource.files(rule)
				else
					config.datasource.search_tags(tags, rule)
				end
				@body= files.collect { |f| webroot + WebFile.url(f) + "\n" }.join
				@size= @body.size
			rescue RuleError => e
				raise e unless e.rule == rule
				@status= 400
				@body= ""
				@size= 0
			end
		end

		def self.url(tags=[], rule= nil)
			rules= if rule
				"&rules="+
				rule.conditions.collect { |a, test, b| "#{a} #{test} #{b}" }.join(" \n ").uri_encode
			else
				""
			end
			"/downloadlist?tags=" + tags.join(" ").uri_encode+rules
		end

	end

end
