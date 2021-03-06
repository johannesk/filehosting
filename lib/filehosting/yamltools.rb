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

require "filehosting/pathname"

require "yaml"
require "fileutils"

module FileHosting

	# a collection of useful YAML methods
	module YAMLTools

		# reads an YAML array from file and checks for correct
		# type
		def self.read_array(file, type)
			return [] unless file.file?
			parse_array(file.read, type)
		end

		# parses an YAML array and checks for correct type
		def self.parse_array(data, type)
			return [] unless data
			begin
				res= YAML.load(data)
			rescue
				raise InternalDataCorruptionError
			end
			raise InternalDataCorruptionError unless Array === res
			res.each do |s|
				raise InternalDataCorruptionError unless type === s
			end
			res
		end

		# stores an object converted to YAML in a file
		def self.store(file, data)
			tmp= file.dirname + (file.basename.to_s + ".tmp")
			begin
				File.open(tmp, "w") do |f|
					f.write(data.to_yaml)
				end
				FileUtils.mv(tmp, file)
			rescue Exception => e
				tmp.delete?
				raise e
			end
		end

		# Manipulates a stored Array. The block must return
		# the new array.
		def self.change_array(file, type, &block)
			array= read_array(file, type)
			array= yield array
			if Array === array
				if array.size == 0
					file.delete?
				else
					store(file, array)
				end
			end
		end

	end

end

