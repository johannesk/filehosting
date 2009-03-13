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

$:<< "../sample"

require "sampledatasource"

require "filehosting/configreader"

require "yaml"

module FileHosting

	# A Class to read a config from a file
	class ConfigFileReader < ConfigReader

		# The file to read from
		attr :file

		def initialize(file)
			@file= file
		end

		def read
			begin
				res= YAML.load(File.read(file))
			rescue
				return Hash.new
			end
			return Hash.new unless Hash === res
			res.each_key do |key|
				next if Symbol === key
				res[key.to_sym]= res[key]
				res.delete(key)
			end
			case res[:datasource]
			when "sample"
				res[:datasource]= SampleDataSource
			end
			res
		end

	end

end

