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
require "filehosting/networkdata"
require "filehosting/internaldatacorruptionerror"
require "filehosting/fileinfo"
require "filehosting/historyevent"

require "socket"

module FileHosting

	# NetworkDataSource is used to connect to a remote datasource
	class NetworkDataSource < DataSource

		attr_accessor :host
		attr_accessor :port

		def initialize(user, host, port)
			super(user)
			@host= host
			@port= port
		end

		# searches for all files with these tags
		def search_tags(tags, rule= nil)
			get= send_query("search_tags") do |query|
				query.add_string(tags.to_yaml)
				query.add_string(rule.to_yaml) if rule
			end
			res= []
			get.size.times do |i|
				res<< YAML.load(get.read_string(i))
				raise InternalDataCorruptionError unless FileInfo === res[-1]
			end
			res
		end

		# searches for all files with at least on of this tags
		def search_tags_partial(tags, rule= nil)
			get= send_query("search_tags_partial") do |query|
				query.add_string(tags.to_yaml)
				query.add_string(rule.to_yaml) if rule
			end
			res= []
			get.size.times do |i|
				res<< YAML.load(get.read_string(i))
				raise InternalDataCorruptionError unless FileInfo === res[-1]
			end
			res
		end

		# returns the fileinfo for the file with this uuid
		def fileinfo(uuid)
			get= send_query("fileinfo") do |query|
				query.add_string(uuid.to_s)
			end
			raise InternalDataCorruptionError unless get.size.size == 1
			res= YAML.load(get.read_string(0))
			raise InternalDataCorruptionError unless FileInfo === res
			res
		end

		# returns the filename as a string
		def filedata_string(uuid)
			if local? # try to get a local filename instead of raw data
				get= send_query("filedata_string") do |query|
					query.add_string(uuid.to_s)
				end
				raise InternalDataCorruptionError unless get.size.size == 1
				file= Pathname.new(get.read_string(0))
				if file.readable?
					return file
				end
			end
			super(uuid)
		end

		# returns an io where the filedata can be read
		def filedata_io(uuid)
			get= send_query("filedata") do |query|
				query.add_string(uuid.to_s)
			end
			get.read_io(0)
		end

		# Adds a file to the datasource. There must be no
		# existing file with the same uuid. Some data from the
		# metadata will not be trusted and replaced by own
		# calculations (eg. filesize). File can ether be an IO
		# or a String. The IO will be read to EOF. The String
		# must contain the filename, from where to copy the
		# file.
		def add_file(fileinfo, file)
			size= -1
			file= Pathname.new(file) if String === file
			if Pathname === file
				size= file.size
				if local? # try to deliver a filename instead of raw data
					get= send_query("add_file_string") do |query|
						query.add_string(fileinfo.to_yaml)
						query.add_string(file.realpath.to_s)
					end
					return if get.read_string(0) == "success"
				end
				file= File.open(file)
			end
			get= send_query("add_file") do |query|
				query.add_string(fileinfo.to_yaml)
				query.add_io(file, size)
			end
			raise InternalDataCorruptionError unless get.size.size == 0
		end

		# Changes the metadata of a file
		def update_fileinfo(fileinfo)
			get= send_query("update_fileinfo") do |query|
				query.add_string(fileinfo.to_yaml)
			end
			raise InternalDataCorruptionError unless get.size.size == 0
		end

		# Replaces a file, but not it's metadata
		def update_filedata(uuid, file)
			size= -1
			file= Pathname.new(file) if String === file
			if Pathname === file
				size= file.size
				if local? # try to deliver a filename instead of raw data
					get= send_query("update_filedata_string") do |query|
						query.add_string(uuid.to_s)
						query.add_string(file.realpath.to_s)
					end
					return if get.read_string(0) == "success"
				end
				file= File.open(file)
			end
			get= send_query("update_filedata") do |query|
				query.add_string(uuid.to_s)
				query.add_io(file, size)
			end
			raise InternalDataCorruptionError unless get.size.size == 1
			res= YAML.load(get.read_string(0))
			raise InternalDataCorruptionError unless FileInfo === res
			res
		end

		# removes a file
		def remove_file(uuid)
			get= send_query("remove_file") do |query|
				query.add_string(uuid.to_s)
			end
			raise InternalDataCorruptionError unless get.size.size == 0
		end

		# returns the history of a user
		def history_user(user= @user)
			get= send_query("history_user") do |query|
				query.add_string(user.to_s)
			end
			res= []
			get.size.times do |i|
				res<< YAML.load(get.read_string(i))
				raise InternalDataCorruptionError unless HistoryEvent === res[-1]
			end
			res
		end

		# returns the history of a file
		def history_file(uuid)
			get= send_query("history_file") do |query|
				query.add_string(uuid.to_s)
			end
			res= []
			get.size.times do |i|
				res<< YAML.load(get.read_string(i))
				raise InternalDataCorruptionError unless FileInfo === res[-1]
			end
			res
		end

		# returns wether the remote host is actually local
		def local?
			@host == "localhost" or
			@host == "::1" or
			@host == "127.0.0.1"
		end

		private

		def send_query(name, &block)
			socket= TCPSocket.new(@host, @port)
			query= NetworkData.new
			query.add_string(name)
			yield query
			socket.print query
			res= NetworkData.new(socket)
			socket.close
			res
		end

	end

end

