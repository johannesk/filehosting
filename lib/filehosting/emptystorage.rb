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

require "filehosting/storage"

module FileHosting

	# EmptyStorage stores nothing.
	class EmptyStorage < Storage

		# Reads a record.
		def read(prefix, name, type= String)
			nil
		end

		# Checks whether a record exists.
		def exists?(prefix, name)
			false
		end

		# Searches all record names for an index.
		def records_by_index(prefix, index)
			[]
		end

		# Returns all record names
		def records(prefix)
			[]
		end

		# Stores an index
		def store_index(prefix, index, name)
		end

		# Stores data.
		def store_data(prefix, name, data)
		end

		# Links one's data to target data.
		def store_link(prefix, name, target)
		end

		# Removes a record.
		def remove(prefix, name)
		end

		# Removes an index for a record.
		def remove_index(prefix, index, name)
		end

	end

end
