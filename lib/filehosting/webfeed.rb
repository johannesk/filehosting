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

require "uuidtools"

module FileHosting

	autoload :InternalDataCorruptionError, "filehosting/internaldatacorruptionerror"

	# A newsfeed
	class WebFeed < WebPage

		def initialize(config, tags, action, age)
			super(config)
			@header["Content-Type"]= "application/atom+xml"
			@cachable= true
			files= if tags == []
				datasource.files
			else
				datasource.search_tags(tags)
			end
			history= files.collect { |f| datasource.history_file(f, age).each { |h| h.entity= f} }
			history.flatten!
			history= history.select do |ev|
				action.include?(ev.action.to_s)
			end
			history.sort! { |a,b| a.time <=> b.time }
			@body= HTML.use_template("feed.eruby", binding)
		end

	end

end
