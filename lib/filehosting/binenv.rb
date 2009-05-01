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

require "filehosting/config"
require "filehosting/autoconfigreader"
require "filehosting/configfilereader"
require "filehosting/configargreader"
require "filehosting/error"

autoload "UUID", "uuidtools"

module FileHosting

	autoload :ConfigSimpleArgReader, "filehosting/configsimpleargreader"

	class BinEnv

		attr_reader :config
		attr_reader :args

		def initialize(*includes, &block)
			@includes= includes
			begin
				autoreader= AutoConfigReader.new
				etcreader= ConfigFileReader.new("/etc/filehostingrc")
				homereader= ConfigFileReader.new("#{ENV["HOME"]}/.filehostingrc")
				localreader= ConfigFileReader.new("./.filehostingrc")
				argreader= includes.find { |i| ConfigArgReader === i} || ConfigArgReader.new
				@args= argreader.parse(ARGV)
				@config= Config.new(autoreader, etcreader, homereader, localreader, argreader)
				block.call(self)
			rescue Error => e
				puts e
				exit 2
			end
		end

		def read_uuid(str)
			begin
				UUID.parse(str)
			rescue ArgumentError => e
				STDERR.puts e
				exit 1
			end
		end

		def read_int(str)
			return str.to_i unless str=~ /[^0-9]/
			STDERR.puts "not a valid integer"
			exit 1
		end

	end

end
