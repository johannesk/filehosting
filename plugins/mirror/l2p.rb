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

require "filehosting/httpmirror"

require "mechanize"
require "hpricot"

module FileHosting

	class Mirror
		
		def plugin_l2p
			L2PMirror
		end

	end

	class L2PMirror < HTTPMirror

		def initialize(config, mirror)
			super(config, mirror)
			unless Hpricot.buffer_size and Hpricot.buffer_size >= 262144
			# increase the Hpricot buffer size to be able
			# to parse ASP pages
				Hpricot.buffer_size = 262144
			end
		end

		# output's messages if needed
		def verbose(message)
			if L2PMirror == self.class and @config[:verbose]
				puts message
			end
		end

		# if an uri is not correct encoded, fix it
		def correct_uri_encoding(str)
			str.gsub(/[^a-zA-Z0-9\-_ \/%.]/) do |c|
				"%#{ c[0]<16 ? "0" : "" }#{ c[0].to_s(16).upcase }"
			end.gsub(" ", "+")
		end

		def uri_from_link(link)
			if link.href and !(link.href=~ /^javascript:/)
				link.page.uri + URI.parse(correct_uri_encoding(link.href))
			end
		end

		# Finds all document url's for an l2p room. If pattern
		# is giving only those matching that pattern.
		def find_urls(url, pattern= nil)
			res= Hash.new
			used= Hash.new
			mechanize= WWW::Mechanize.new
			if auth= find_auth(:http_basic_auth, url.to_s)
			# use auth if info available
				mechanize.auth(auth.identifier, auth.auth_data)
			end
			
			begin
				links= mechanize.get(url+= URI.parse("materials/default.aspx")).links
			rescue
				verbose("could not read url '#{url}'")
				return []
			end

			while links.size > 0
				newlinks= []
				links.each do |link|
					next unless href= uri_from_link(link)
					case link.href
					when /\/materials\/default.aspx|\/exerciseCourse\/(default.aspx|AssignmentSheets\/display.aspx\?)/
						unless used[href]
							begin
								newlinks+= mechanize.click(link).links
							rescue
								next
							end
							used[href]= true
						end
					when  /\/materials\/documents\/Forms\/all.aspx/
					when  /\/materials\/structured\/Forms\/all.aspx/
					when  /\/(materials\/(documents|structured)|exerciseCourse\/Assignment(Documents|Attachments))\/./
						res[href]= true
					end
				end
				links= newlinks
			end

			res= res.keys
			puts res
			if res.size == 0
				verbose("no url's on page found '#{url}'")
				return res
			elsif pattern
				res= res.select { |l| l.to_s=~ pattern }
				if res.size == 0
					verbose("no url's for pattern found '#{url}' #{pattern.inspect}")
				end
			end
			res
		end

	end

end
