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
				count= config.datasource.count do
					block.call(self)
				end
				if ENV["DEBUG"]
					STDERR.puts "#{config.storage.count_read} reads"
					STDERR.puts "#{config.storage.count_write} writes"
					STDERR.puts "#{count.keys.size} different operations"
					STDERR.puts "#{count.values.inject(0) { |a,b| a+b }} total operations"
					max= count.keys.inject(0) do |last, op, num,|
						size= op.size+10+num.to_s.size
						if size >= last
							size
						else
							last
						end
					end
					count.each do |op, num|
						STDERR.puts op + " "*(max-op.size-num.to_s.size) + num.to_s
					end
				end
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