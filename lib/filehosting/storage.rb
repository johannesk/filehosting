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

require "filehosting/prefixedstorage"

module FileHosting

	# Storage stores any kind of data. Storage is not a usable
	# class. It is only intended as parent class for real
	# Storage's.
	class Storage

		# Stores data and index's to it.
		def store(prefix, name, data, index, date= nil)
			store_safe(prefix, name, index, date || Time.now) do
				store_data(prefix, name, data)
			end
		end

		# The same as store but data is the data of the target
		# record.
		def link(prefix, name, target ,index, date= nil)
			store_safe(prefix, name, index, date || Time.now) do
				store_link(prefix, name, target)
			end
		end

		# Returns a prefixed storage.
		def prefix(prefix)
			PrefixedStorage.new(prefix, self)
		end

		# The following 9 methods should be implemented by all
		# child classes of Storage.

		# Reads a record.
		def read(prefix, name, type)
			raise NotImplementedError
		end

		# Reads the date of a record
		def date(prefix, name)
			raise NotImplementedError
		end

		# Checks whether a record exists.
		def exists?(prefix, name)
			raise NotImplementedError
		end

		# Searches all record names for an index.
		def index(prefix, index)
			raise NotImplementedError
		end

		# Searches all index's for a record or all records.
		def reverse(prefix, name= nil)
			raise NotImplementedError
		end

		# Returns all record names
		def records(prefix)
			raise NotImplementedError
		end

		# Stores an index
		def store_index(prefix, index, name)
			raise NotImplementedError
		end

		# Stores data.
		def store_data(prefix, name, data)
			raise NotImplementedError
		end

		# Links one's data to target data.
		def store_link(prefix, name, target)
			raise NotImplementedError
		end

		# Set's the date of a record
		def set_date(prefix, name, date)
			raise NotImplementedError
		end

		# Removes the date of a record
		def remove_date(prefix, name)
			raise NotImplementedError
		end

		# Removes a record.
		def remove(prefix, name)
			raise NotImplementedError
		end

		# Removes an index for a record.
		def remove_index(prefix, index, name)
			raise NotImplementedError
		end

		private

		def store_safe(prefix, name, index, date, &block)
			index= [index].flatten
			rev= reverse(prefix, name)
			plus= index - rev
			minus= rev - index
			begin
				plus.each do |ind|
					store_index(prefix, ind, name)
				end
				minus.each do |ind|
					remove_index(prefix, ind, name)
				end
				set_date(prefix, name, date)
				block.call
			rescue Exception => e
				plus.each do |ind|
					remove_index(prefix, ind, name)
				end
				minus.each do |ind|
					store_index(prefix, ind, name)
				end
				remove_date(prefix, name)
				raise e
			end
		end

	end

end
