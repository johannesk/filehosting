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

	# A PrefixedStorage has the same methods as Storage. No prefix
	# needs to be given to any method.
	class PrefixedStorage

		attr_reader :prefix
		attr_reader :storage

		def initialize(prefix, storage)
			@prefix= prefix
			@storage= storage
		end

		# Stores data and index's to it.
		def store(name, data, index)
			@storage.store(@prefix, name, data, index)
		end

		# The same as store but data is the data of the target
		# record.
		def link(name, target ,index)
			@storage.link(@prefix, name, target, index)
		end

		# Reads a record.
		def read(name, type= String)
			@storage.read(@prefix, name, type)
		end

		# Reads the date of a record
		def date(name)
			@storage.date(@prefix, name)
		end

		# Checks whether a record exists.
		def exists?(name)
			@storage.exists?(@prefix, name)
		end

		# Searches all records for an index.
		def index(index)
			@storage.index(@prefix, index)
		end

		# Check whether records with this index exists.
		def index_exists?(index)
			@storage.index_exists?(@prefix, index)
		end

		# Searches all index's for a record or all records.
		def reverse(name= nil)
			@storage.reverse(@prefix, name)
		end

		# Returns all record names
		def records
			@storage.records(@prefix)
		end

		# Stores an index
		def store_index(index, name)
			@storage.store_index(@prefix, index, name)
		end

		# Stores data.
		def store_data(name, data)
			@storage.store_data(@prefix, name, data)
		end

		# Links one's data to target data.
		def store_link(name, target)
			@storage.store_link(@prefix, name, target)
		end

		# Set's the date of a record
		def set_date(name, date)
			@storage.set_date(name, date)
		end

		# Removes the date of a record
		def remove_date(name)
			@storage.remove_date(prefix, name)
		end

		# Removes a record.
		def remove(name)
			@storage.remove(@prefix, name)
		end

		# Removes an index for a record.
		def remove_index(index, name)
			@storage.remove_index(@prefix, index, name)
		end

	end

end
