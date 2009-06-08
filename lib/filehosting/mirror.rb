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
require "filehosting/mirrorfile"
require "filehosting/nosuchfileerror"

require "observer"
require "uuidtools"

module FileHosting

	autoload :InternalDataCorruptionError, "filehosting/internaldatacorruptionerror"
	autoload :PluginError, "filehosting/pluginerror"

	class Mirror

		include Observable

		def notify_observers(*args)
			changed
			super(*args)
		end

		def update(*args)
			notify_observers(*args)
		end

		def initialize(config)
			@config= config
			@storage= config.storage.prefix("mirror")
			@plugins= Hash.new
		end

		def register(name, location)
			list= location_list(name)
			list<< location
			store_location_list(name, list)
		end

		def remove(name, location)
			list= location_list(name)
			list.delete_if do |l|
				l.type == location.type and l.location == location.location
			end
			store_location_list(name, list)
		end

		# checks for new and changed files
		def check(name)
			locations= location_list(name)
			files= file_list(name)
			locations.each do |loc|
				lfiles= files[loc.type]
				replaced_files= nil
				check_plugin_error do
					replaced_files= plugin_by_name(loc.type).check_replace(loc, lfiles)
				end
				do_check_return(lfiles, replaced_files) do |fileinfo, filedata|
					@config.datasource.update_filedata(fileinfo, filedata)
					@config.datasource.update_fileinfo(fileinfo)
				end
				new_files= nil
				check_plugin_error do
					new_files= plugin_by_name(name).check_new(loc, lfiles)
				end
				do_check_return(lfiles, replaced_files) do |fileinfo, filedata|
					@config.datasource.add_file(fileinfo, filedata)
				end
			end
			store_file_list(name, files)
		end

		def location_list(name)
			list= @storage.read(location_list_name(name))
			return [] unless list
			list= YAMLTools.parse_array(list, MirrorLocation)
			list
		end

		private

		def do_check_return(files, array, &block)
			raise ArgumentError.new("plugin.check_* should return an array of [fileinfo, filedata, data]") unless Array === array
			array.each do |a|
				check_plugin_error do
					raise ArgumentError.new("plugin.check_* should return an array of [fileinfo, filedata, data]") unless a.size == 3
				end
				fileinfo= a[0]
				filedata= a[1]
				data= a[2]
				check_plugin_error do
					raise ArgumentError.new("plugin.check_* should return an array of [fileinfo, filedata, data]") unless FileInfo <= fileinfo.class
				end
				yield(fileinfo, filedata)
				files[fileinfo.uuid]= [fileinfo, data]
			end
		end

		def plugin_by_name(name)
			raise ArgumentError.new("plugin name can containt only a-zA-Z0-9_") if name=~ /[^a-zA-Z0-9_]/
			unless @plugins[name]
				check_plugin_error do
					unless self.respond_to("plugin_#{name}")
						require "plugins/mirror/#{name}"
					end
					@plugins[name]= eval("self.plugin_#{name}").new(config)
					@plugins[name].register_observer(self)
				end
			end
			@plugins[name]
		end

		def check_plugin_error(&block)
			begin
				yield
			rescue Exception => e
				raise PluginError.new(e)
			end
		end


		# the file list is saved as the following { :plugin => [["uuid", data]] }
		# the file list is intenaly as the following { :plugin => { uuid => [fileinfo, data]} }
		def file_list(name)
			list= @storage.read(file_list_name(name))
			return {} unless list
			list= YAML.load(list)
			raise InternalDataCorruption unless Hash === list
			res= {}
			list.each do |key, a|
				raise IntenralDataCorruption unless Symbol === key
				raise IntenralDataCorruption unless Array === a
				r= Hash.new
				a.each do |b|
					raise IntenralDataCorruption unless Array === b
					raise IntenralDataCorruption unless b.size == 2
					begin
						uuid= UUID.parse(b[0])
					rescue ArgumentError
						raise InternalDataCorruptionError
					end
					begin
						fileinfo= @config.datasource.fileinfo(uuid)
					rescue NoSuchFileError
						raise InternalDataCorruptionError
					end
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
					res[key]= a.collect do |uuid, v|
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

		def file_list_name(name)
			"files/#{name}"
		end

		def location_list_name(name)
			"locations/#{name}"
		end

	end

end
