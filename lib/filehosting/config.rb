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

require "filehosting/datasource"

module FileHosting

	# This Class holds the Configuration
	class Config

		attr :values

		# An instant of a subclass of DataSource
		attr :datasource

		def initialize(*data)
			@values= {
				:datasource      => DataSource,
				:datasource_args => [],
				:human           => false,
				:user            => "unknown"
			}
			data.each do |d|
				@values.merge!(case d
				when Hash
					d
				when ConfigReader
					d.read
				end)
			end
			$human= @values[:human]
			@values[:datasource]= self.class.datasource_by_name(@values[:datasource]) if @values[:datasource]
			@datasource= @values[:datasource].new(@values[:user], *@values[:datasource_args])
		end

		# Returns a subclass of Datasource only by its name
		# possible values are:
		# - sample
		def self.datasource_by_name(name)
			return name if name == DataSource
			case name.to_s
			when "sample"
				require "filehosting/sampledatasource"
				SampleDataSource
			when "file"
				require "filehosting/filedatasource"
				FileDataSource
			end
		end

	end

end

