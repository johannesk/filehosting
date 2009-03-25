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
require "filehosting/nosuchfileerror"
require "filehosting/fileexistserror"

module FileHosting

	# This DataSource knows nothing
	class EmptyDataSource < DataSource

		# searches for all files with these tags
		def search_tags(tags)
			[]
		end

		# searches for all files with at least on of this tags
		def search_tags_partial(tags)
			[]
		end

		# returns the fileinfo for the file with this uuid
		def fileinfo(uuid)
			raise NoSuchFileError.new(uuid)
		end

		# returns the filename as a string
		def filedata_string(uuid)
			raise NoSuchFileError.new(uuid)
		end

		# returns an io where the filedata can be read
		def filedata_io(uuid)
			File.open(filedata_string(uuid))
		end

		# Adds a file to the datasource. There must be no
		# existing file with the same uuid. Some data from the
		# metadata will not be trusted and replaced by own
		# calculations (eg. filesize). File can ether be an IO
		# or a String. The IO will be read to EOF. The String
		# must contain the filename, from where to copy the
		# file.
		def add_file(fileinfo, file)
			raise FileExistsError.new(fileinfo.uuid)
		end

		# Changes the metadata of a file
		def update_fileinfo(fileinfo)
			raise NoSuchFileError.new(uuid)
		end

		# Replaces a file, but not it's metadata
		def update_filedata(uuid, file)
			raise NoSuchFileError.new(uuid)
		end

		# removes a file
		def remove_file(uuid)
		end

		# returns the history of a user
		def history_user(user= @user)
			[]
		end

		# returns the history of a file
		def history_file(uuid)
			[]
		end

	end

end

