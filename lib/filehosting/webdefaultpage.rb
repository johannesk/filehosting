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
require "filehosting/html"

module FileHosting

	# The parent of all html WebPages
	class WebDefaultPage < WebPage

		def initialize(config, title, body, *includes)
			header= @header
			status= @status
			tags= @tags
			cachable= @cachable
			super(config)
			@header["Content-Type"]= "text/html; charset=utf-8"
			@body= HTML.use_template("default.eruby", binding)
			@cachable= true
			@header.merge(header) unless header.nil?
			@status= status unless status.nil?
			@tags= tags+@tags unless tags.nil?
			@cachable= cachable unless cachable.nil?
		end

		def size
			@body.size
		end

	end

end
