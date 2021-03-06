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

require "filehosting/yamltools"
require "filehosting/mirrorlocation"
require "filehosting/nosuchfileerror"
require "filehosting/mirrorlocation"
require "filehosting/mirrorauth"

require "observer"
require "filehosting/uuid"

module FileHosting

	autoload :InternalDataCorruptionError, "filehosting/internaldatacorruptionerror"
	autoload :PluginError, "filehosting/pluginerror"

	# This class handles mirror locations. It remembers which
	# locations to mirror. If asked it checks all files in the to
	# be mirrored locations for changes.
	#
	# Every location gets a name. Multiple locations can have the
	# same name. locations with the same name can not be checked
	# for updates individually.
	#
	# This class does not know how to mirror. The mirroring itself
	# is delegated to the mirroring plugins. To see how to write
	# your own plugins look at MirrorPlugin and the existing
	# plugin HTTPMirror. All added plugins should live in
	# 'plugins/mirror/'.
	class Mirror

		def plugin_http
			require "filehosting/httpmirror"
			FileHosting::HTTPMirror
		end

		include Observable

		def notify_observers(*args)
			changed
			super(*args)
		end

		# this methods should only be called from Observable
		def update(*args)
			check_plugin_error do
				raise ArgumentError.new("notify_observers needs these arguments: (type, url, uuid)") unless args.size == 3
				raise ArgumentError.new("notify_observers needs these arguments: (type, url, uuid)") unless [:create, :update].include?(args[0])
				raise ArgumentError.new("notify_observers needs these arguments: (type, url, uuid)") unless String === args[1]
				raise ArgumentError.new("notify_observers needs these arguments: (type, url, uuid)") unless UUIDTools::UUID === args[2]
			end
			notify_observers(*args)
			@update_list<< args[2]
		end

		def initialize(config)
			@config= config
			@storage= config.storage.prefix("mirror")
			@plugins= Hash.new
			@update_list= []
		end

		# register a location to be mirrored
		def register(name, location)
			list= location_list(name)
			list<< location
			store_location_list(name, list)
		end

		# remove a location from the list of locations to be
		# mirrored
		def remove(name, location)
			list= location_list(name)
			list.delete_if do |l|
				l.type == location.type and
				l.location == location.location and
				l.pattern == location.pattern
			end
			store_location_list(name, list)
		end

		# checks for new and changed files
		def check(name)
			@update_list= []
			locations= location_list(name)
			files= file_list(name)
			files.each do |type, filelist|
				replaced_files= nil
				check_plugin_error do
					replaced_files= plugin_by_name(type).check_update(filelist)
				end
				do_check_return(filelist, replaced_files) do |fileinfo, filedata, data, human_readable|
					@config.datasource.update_filedata(fileinfo, filedata)
					@config.datasource.update_fileinfo(fileinfo)
					notify_observers(:update, human_readable, fileinfo.uuid) unless @update_list.include?(fileinfo.uuid)
				end
			end
			locations.each do |loc|
				lfiles= files[loc.type]
				new_files= nil
				check_plugin_error do
					new_files= plugin_by_name(loc.type).check_new(loc, lfiles)
				end
				do_check_return(lfiles, new_files) do |fileinfo, filedata, data, human_readable|
					fileinfo.tags= self.class.grep_tags(loc.tags, human_readable.match(loc.pattern))
					fileinfo.source= data
					fileinfo.source= loc.source if loc.source and !loc.source.empty?
					@config.datasource.add_file(fileinfo, filedata)
					notify_observers(:create, human_readable, fileinfo.uuid) unless @update_list.include?(fileinfo.uuid)
				end
			end
			store_file_list(name, files)
		end

		# Returns an array of all suitable Auth objects for
		# the given arguments. The array is sorted by most
		# specific location first.
		def find_auth_all(auth_type, location)
			auth_by_type(auth_type).collect do |auth| 
			# the prefix length for each auth
				[auth.usable_in?(location), auth]
			end.select do |length, auth|
			# only auth with existing prefix length
				length
			end.sort do |a, b|
			# sort by prefix length. Longest first.
				b[0] <=> a[0]
			end.collect do |length, auth|
			# only auth not length
				auth
			end
		end

		# Retuns the most specific auth object for the given
		# arguments.
		def find_auth(auth_type, location)
			find_auth_all(auth_type, location)[0]
		end

		# Returns an arry of all Auth objects for this type
		def auth_by_type(auth_type)
			list= @storage.read(auth_list_name(auth_type))
			return [] unless list
			list= YAMLTools.parse_array(list, Mirror::Auth)
			list
		end

		# adds an Auth object to the storage
		def add_auth(auth)
			list= auth_by_type(auth.auth_type)
			list<< auth
			store_auth_list(auth.auth_type, list)
		end

		# removes an Auth object from the storage
		def remove_auth(auth)
			list= auth_by_type(auth.auth_type)
			list.delete_if do |a|
				a.identifier == auth.identifier and
				a.locations.sort == auth.locations.sort
			end
			store_auth_list(auth.auth_type, list)
		end

		# replaces \1 .. \9 in tags with data from mdata
		def self.grep_tags(tags, mdata)
			tags.collect do |tag|
				tag.gsub(/\\([1-9%])/) do
					s= $1
					case s
					when "%"
						"\\"
					else
						mdata[s.to_i]
					end
				end
			end
		end

		# Returns an array of all locations to be mirrored
		# for this name.
		def locations(name)
			list= @storage.read(location_list_name(name))
			return [] unless list
			list= YAMLTools.parse_array(list, Mirror::Location)
			list
		end
		alias :location_list :locations

		private

		def do_check_return(files, array, &block)
			raise ArgumentError.new("plugin.check_* should return an array of [fileinfo, filedata, data, human_readable]") unless Array === array
			array.each do |a|
				check_plugin_error do
					raise ArgumentError.new("plugin.check_* should return an array of [fileinfo, filedata, data, human_readable]") unless a.size == 4
				end
				fileinfo= a[0]
				filedata= a[1]
				data= a[2]
				human_readable= a[3]
				check_plugin_error do
					raise ArgumentError.new("plugin.check_* should return an array of [fileinfo, filedata, data, human_readable]") unless FileInfo <= fileinfo.class
				end
				yield(fileinfo, filedata, data, human_readable)
				files[fileinfo.uuid]= [fileinfo, data]
			end
		end

		def plugin_by_name(name)
			raise ArgumentError.new("plugin name can containt only a-zA-Z0-9_") if name=~ /[^a-zA-Z0-9_]/
			unless @plugins[name]
				check_plugin_error do
					unless self.respond_to?("plugin_#{name}")
						require "plugins/mirror/#{name}"
					end
					@plugins[name]= send(:"plugin_#{name}").new(@config, self)
					@plugins[name].add_observer(self)
				end
			end
			@plugins[name]
		end

		def check_plugin_error(&block)
			begin
				yield
			rescue PluginError => e
				raise e
			rescue Exception => e
				raise PluginError.new(e)
			end
		end


		# the file list is saved as the following { :plugin => [["uuid", data]] }
		# the file list is used as the following { :plugin => { uuid => [fileinfo, data]} }
		def file_list(name)
			list= @storage.read(file_list_name(name))
			res= Hash.new { |h, k| h[k]= {} }
			return res unless list
			list= YAML.load(list)
			raise InternalDataCorruptionError unless Hash === list
			list.each do |key, a|
				key= key.to_s.to_sym
				raise InternalDataCorruptionError unless Array === a
				r= Hash.new
				a.each do |b|
					raise InternalDataCorruptionError unless Array === b
					raise InternalDataCorruptionError unless b.size == 2
					begin
						uuid= UUIDTools::UUID.parse(b[0])
					rescue ArgumentError
						raise InternalDataCorruptionError
					end
					begin
						fileinfo= @config.datasource.fileinfo(uuid)
					rescue NoSuchFileError
						raise InternalDataCorruptionError
					end
					data= b[1].to_s
					r[uuid]= [fileinfo, data]
				end
				res[key]= r
			end
			res
		end

		def store_file_list(name, list)
			name= file_list_name(name)
			if list.size == 0
				@storage.remove(name)
			else
				res= Hash.new
				list.each do |key, a|
					res[key.to_s]= a.collect do |uuid, v|
						[uuid.to_s, v[1]]
					end
				end
				@storage.store_data(name, res.to_yaml)
			end
		end

		def store_location_list(name, list)
			name= location_list_name(name)
			if list.size == 0
				@storage.remove(name)
			else
				@storage.store_data(name, list.to_yaml)
			end
		end

		def store_auth_list(auth_type, list)
			name= auth_list_name(auth_type)
			if list.size == 0
				@storage.remove(name)
			else
				@storage.store_data(name, list.to_yaml)
			end
		end

		def file_list_name(name)
			"files/#{name.dir_encode}"
		end

		def location_list_name(name)
			"locations/#{name.dir_encode}"
		end

		def auth_list_name(auth_type)
			"auth/#{auth_type.to_s.dir_encode}"
		end

	end

end
