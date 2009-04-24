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

module FileHosting

	# The Cache caches files and automaticly deletes them,
	# when they are outdated.
	class Cache

		def initialize(config)
			@config= config
			@storage= config.storage.prefix("cache")
		end

		# Stores a file in the cache.
		def store(name, data, deps, date= nil)
			@storage.store(name, data, deps)
		end

		# stores a file as link to another file
		def store_link(name, target, deps, date= nil)
			@storage.link(name, target, deps)
		end

		# Reads a file from the cache. If the requested file
		# does not exist, it can be created with the return
		# value of a block. The block must return an Array of
		# the following form [data, [tag, ..., tag]]. If the
		# file was created the data is returned.
		def retrieve(name, type= String)
			data= @storage.read(name, type)
			unless data
				return nil unless block_given?
				data, deps= yield
				return nil unless data
				deps= [] unless deps
				@storage.store(name, data, deps)
			end
			data
		end

		# Reads the date of a file in the cache.
		def date(name)
			@storage.date(name)
		end

		# Reads the tags of a file in the cache
		def tags(name)
			@storage.reverse(name)
		end

		# Deletes all files with this dependencies.
		def delete_for_deps(deps)
			[deps].flatten.each do |dep|
				@storage.index(dep).each do |file|
					@storage.remove(file)
				end
			end
		end
		alias :update :delete_for_deps

		# deletes everything in the cache
		def clear
			@storage.records.each do |file|
				@storage.remove(file)
			end
		end

	end

end
