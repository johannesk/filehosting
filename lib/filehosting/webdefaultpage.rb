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
require "filehosting/webdefaultpart"

module FileHosting

	# The parent of all html WebPages
	class WebDefaultPage < WebPage

		# Body is the body to be embedded between the header
		# and footer of the page. If title or body is not
		# given a block must be given which will return 
		# [title, body].
		def initialize(config, title= nil, body= nil)
			unless (title and body) or block_given?
				raise ArgumentError.new("ether title and body or a block must be given")
			end

			# Save some variables, so they don't get
			# overwritten by super(). The content of this
			# variables origins from child classes of
			# WebDefaultPage.
			header= @header
			status= @status
			cachable= @cachable
			super(config)
			@header["Content-Type"]= "text/html; charset=utf-8"
			@cachable= true
			@header.merge(header) unless header.nil?
			@status= status unless status.nil?
			@cachable= cachable unless cachable.nil?

			# get the body if not already given
			title, body= yield unless title and body
			@body= self.class.indent(use_part(WebDefaultPart, title, body, includes))
		end

		def size
			@body.size
		end

		def use_part(partclass, *args)
			begin
				# save the current webpage this part is for
				webpage= Thread.current[:"filehosting/webpage"]
				unless webpage
					webpage= []
					Thread.current[:"filehosting/webpage"]= webpage
				end
				webpage<< self

				part= if block_given?
					partclass.new(config, *args) { |*x| yield(*x) }
				else
					partclass.new(config, *args)
				end
			rescue ArgumentError
				raise "wrong arguments for '#{partclass}': '#{args.inspect}'"
			ensure
				webpage.pop
			end
			part.body
		end

		# An array of all stylesheet and javascript files to
		# be included in this page.
		def includes
			@includes || []
		end

		# Includes a stylesheet or javascript file into the
		# page.
		def use(usethis)
			@includes= ((@includes || []) + [usethis]).uniq
		end

		# Indents the html page. Only works if start and end
		# tags do not share there line with other tags, or
		# start tags are closed on the same line. Even if
		# indenting is broken, the resulting html tree will
		# never be brocken.
		def self.indent(html)
			indent= 0
			html.collect do |line|
				line=~ /^\t*(.*?)\n?$/
				line= $1
				offset= case line
				when ""
				# remove empty lines
					next ""
				when /^<[a-z]+(\s+[a-z]+=\"[^>]*?\")*\s*>$/
				# start tag found
					indent+= 1
					-1
				when /^<\/[a-z]+>$/
				# end tag found
					indent-= 1 if indent > 0
					0
				else
					0
				end
				"\t"*(indent+offset) + line + "\n"
			end.join
		end

	end

end
