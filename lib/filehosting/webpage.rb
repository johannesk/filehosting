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

require "filehosting/string"

module FileHosting

	autoload :WebFileInfoPart, "filehosting/webfileinfopart"
	autoload :WebFileInfoButtonPart, "filehosting/webfileinfobuttonpart"
	autoload :WebUpdateButtonPart, "filehosting/webupdatebuttonpart"
	autoload :WebRemoveButtonPart, "filehosting/webremovebuttonpart"
	autoload :WebFileHistoryButtonPart, "filehosting/webfilehistorybuttonpart"
	autoload :WebTagSearchPart, "filehosting/webtagsearchpart"
	autoload :WebSearchBoxPart, "filehosting/websearchboxpart"

	# The parent of all WebPages
	class WebPage

		attr_reader :header
		attr_reader :status
		attr_reader :config
		attr_reader :cachable
		attr_reader :date
		attr_reader :error_handled
		attr_reader :body
		protected :body

		def initialize(config)
			@config= config
			@status= 200 unless instance_variable_defined?(:@status)
			@header= Hash.new unless instance_variable_defined?(:@header)
			@date= Time.now unless instance_variable_defined?(:@date)
			@error_handled= false unless instance_variable_defined?(:@erro_handled)
		end

		def to_output
			[
				header.collect do |key, value|
					"#{key}: #{value}\n"
				end.join +
				(size ? "Content-Length: #{size}\n" : "") +
				"Status: #{status}\n" +
				"Last-Modified: #{date.httpdate}\n" +
				"\n",
				body
			]
		end

		def size
			if String === @body
				body.size
			else
				nil
			end
		end

		def webroot
			config[:webroot]
		end

		def datasource
			config[:datasource]
		end

		def user
			datasource.current_user
		end

		# Each WebPage child should implement how to build the
		# url to reach it.
		def self.url(*args)
			raise NotImplementedError
		end

	end

end

