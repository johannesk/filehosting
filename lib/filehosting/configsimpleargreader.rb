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

require "filehosting/configargreader"

module FileHosting

	class ConfigSimpleArgReader < ConfigArgReader

		def initialize(args, iarg= nil)
			super()
			@args= args || []
			@iarg= iarg
		end

		def banner
			super + " " + (@args.collect { |a| "<#{a}>" } +
			case @iarg
			when String
				["<#{@iarg} ... #{@iarg}>"]
			when Array
				@iarg.collect { |a| "[#{a}]" }
			else
				[]
			end).join(" ")
		end

		def arg_count
			case @iarg
			when String
				((@args.size+1)..(1.0/0))
			when Array
				((@args.size)..(@args.size+@iarg.size))
			else
				@args.size
			end
		end

	end

end
