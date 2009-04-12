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
require "text"

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
		def initialize(config)
			@config= config
		end

		# The following methods should be reimplemented in a
		# child class of DataSource.

		# searches for all files with these tags
		def search_tags(tags, rule= nil)
			raise NotImplementedError
		end

		# searches for all files with at least on of this tags
		def search_tags_partial(tags, rule=nil)
			raise NotImplementedError
		end

		# returns all available tags
		def tags
			raise NotImplementedError
		end

		# returns the fileinfo for the file with this uuid
		def fileinfo(uuid)
			raise NotImplementedError
		end

		# returns the filedata
		def filedata(uuid, type= File)
			raise NotImplementedError
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

		# returns the history of a file
		def history_file(uuid)
			raise NotImplementedError
		end

		# returns information about a user
		def user(username= nil)
			raise NotImplementedError
		end

		# creates a new user
		def add_user(user)
			raise NotImplementedError
		end

		# updates a user
		def update_user(user)
			raise NotImplementedError
		end

		# removes a user
		def remove_user(username)
			raise NotImplementedError
		end

		# returns the history of a user
		def history_user(user= @user)
			raise NotImplementedError
		end

		# The following methods need not to be reimplemented
		# in a child class of DataSource.

		# Returns a better set of search tags
		def optimize_search(*search)
			search.flatten!
			search.uniq!
			available= tags
			(search-tags).each do |wrong|
				better= @config.cache.retrieve("search_optimize/"+wrong.dir_encode) do
					available.sort! { |a,b| (a.size-wrong.size).abs <=> (b.size-wrong.size).abs }
					found= nil
					min= 1.0/0
					s= 0
					catch :finished do
						available.each do |tag|
							throw :finished if (wrong.size - tag.size).abs > min
							r= Text::Levenshtein.distance(tag, wrong)
							n= (tag.split(//) & wrong.split(//)).size
							next if n == 0
							if r < min
								min= r
								found= tag
								s= 0
							elsif r == min
								if n > s
									s= n
									found= tag
								end
							end
						end
					end
					[found || "", ["tags"]]
				end
				search[search.index(wrong)]= better unless better.empty?
			end
			search
		end

	end

end

