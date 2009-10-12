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

require "filehosting/cache"

require "pathname"

module FileHosting

	autoload :EmptyStorage, "filehosting/emptystorage"
	autoload :FileStorage, "filehosting/filestorage"
	autoload :EmptyDataSource, "filehosting/emptydatasource"
	autoload :SampleDataSource, "filehosting/sampledatasource"
	autoload :StorageDataSource, "filehosting/storagedatasource"

	# This Class holds the Configuration
	class Config

		attr :values

		def initialize(*data)
			@values= {
				:name            => "FileHosting",
				:datasource_args => [],
				:storage_args    => [],
				:human           => false,
				:user            => "unknown",
				:webroot         => "",
				:username        => "anonymous",
				:password        => "",
				:webroot         => "",
				:default_search  => [],
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
			@values[:storage]= self.class.storage_by_name(@values[:storage])
			@values[:storage]= @values[:storage].new(*@values[:storage_args])
			@values[:cache]= Cache.new(self)
			@values[:datasource]= self.class.datasource_by_name(@values[:datasource])
			@values[:datasource]= @values[:datasource].new(self, *@values[:datasource_args])
			@values[:datasource].add_observer(@values[:cache])
		end

		def [](key)
			@values[key]
		end

		def datasource
			@values[:datasource]
		end

		def cache
			@values[:cache]
		end

		def storage
			@values[:storage]
		end

		def user
			@values[:user]
		end

		# Returns a subclass of Datasource only by its name
		# possible values are:
		# - emtpy
		# - sample
		# - storage
		def self.datasource_by_name(name)
			case name.to_s
			when "sample"
				SampleDataSource
			when "storage"
				StorageDataSource
			else
				EmptyDataSource
			end
		end

		# Returns a subclass of Storage only by its name
		# possible values are:
		# - empty
		# - file
		def self.storage_by_name(name)
			case name.to_s
			when "file"
				FileStorage
			else
				EmptyStorage
			end
		end

	end

end
