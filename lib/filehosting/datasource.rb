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

require "filehosting/nosuchfileerror"
require "filehosting/fileexistserror"
require "filehosting/file"

require "observer"

module FileHosting

	# The DataSource knows everything
	class DataSource

		include Observable

		def notify_observers(*arg)
			changed
			super
		end

		attr_reader :user

		# You always have to specify a user
		def initialize(user)
			@user= user
		end

		# searches for all files with these tags
		def search_tags(tags)
		end

		# searches for all files with at least on of this tags
		def search_tags_partial(tags)
		end

		# returns all available tags
		def tags
		end

		# returns the fileinfo for the file with this uuid
		def fileinfo(uuid)
		end

		# returns the filename as a string
		def filedata_string(uuid)
			io= filedata_io(uuid)
			File.mktemp(file, "w") do |f|
				IO2IO.do(io, f)
				f.path
			end
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
			notify_observers("files/#{fileinfo.uuid}")
			fileinfo.tags.each do |tag|
				notify_observers("tags/#{tag}")
			end
			notify_observers("tags") unless (fileinfo.tags - tags).empty?
		end

		# Changes the metadata of a file
		def update_fileinfo(fileinfo)
			notify_observers("files/#{fileinfo.uuid}")
			new= fileinfo.tags
			old= self.fileinfo(fileinfo.uuid).tags
			plus= new - old
			minus= old - new
			(plus + minus).each do |tag|
				notify_observers("tags/#{tag}")
			end
			if not (plus - tags).empty? or minus.find { |tag| search_tags([tag]).size == 1 }
				notify_observers("tags")
			end
		end

		# Replaces a file, but not it's metadata.
		# Returns the fileinfo
		def update_filedata(uuid, file)
			notify_observers("files/#{uuid}")
		end

		# removes a file
		def remove_file(uuid)
			notify_observers("files/#{uuid}")
			tags= fileinfo(uuid).tags
			if tags.find { |tag| search_tags([tag]).size == 1 }
				notify_observers("tags")
			end
		end

		# returns the history of a user
		def history_user(user= @user)
		end

		# returns the history of a file
		def history_file(uuid)
		end

	end

end

