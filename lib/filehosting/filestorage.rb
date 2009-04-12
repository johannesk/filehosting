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
require "filehosting/string"
require "filehosting/yamltools"
require "filehosting/pathname"

require "fileutils"
require "pathname"

require "io2io"

module FileHosting

	# FileStorage implements a Storage, where all data is saved 
	# just in the filesystem.
	class FileStorage < Storage

		def initialize(dir)
			dir= Pathname.new(dir) unless Pathname === dir
			dir.mkpath unless dir.directory?
			@dir= dir
		end


		# Reads a record.
		def read(prefix, name, type= String)
			file= prefix_data_file(prefix, name)
			return nil unless file.file?
			case
			when type == String
				file.read
			when type == File
				File.new(file)
			when type == IO
				File.new(file)
			else
				raise NotImplementedError
			end
		end

		# Checks whether a record exists.
		def exists?(prefix, name)
			prefix_data_file(prefix, name).file?
		end

		# Searches all records for an index.
		def index(prefix, index)
			YAMLTools.read_array(prefix_index_file(prefix, index), String)
		end

		# Searches all index's for a record
		def reverse(prefix, name= nil)
			if name
				YAMLTools.read_array(prefix_reverse_file(prefix, name), String)
			else
				prefix_index_dir(prefix).children.collect { |p| p.basename.to_s.dir_decode }
			end
		end

		# Returns all record names
		def records(prefix)
			prefix_data_dir(prefix).children.collect { |p| p.basename.to_s.dir_decode }
		end

		# Stores an index
		def store_index(prefix, index, name)
			return if self.index(prefix, name).include?(index)
			begin
				add_index(prefix, index, name)
			rescue Exception => e
				rm_index(prefix, index, name)
				raise e
			end
		end
		
		# Stores data.
		def store_data(prefix, name, data)
			file= prefix_data_file(prefix, name)
			tmp= file.dirname + (file.basename.to_s + ".tmp")
			data= [data].flatten
			begin
				if File === data[0]
						FileUtils.cp(data.shift.path, tmp)
				end
				File.open(tmp, "w") do |f|
					data.each do |d|
						case d
						when String
							f.write(d)
						when IO
							IO2IO.do(d, f)
						else
							raise NotImplementedError
						end
					end
				end
				FileUtils.mv(tmp, file)
			rescue Exception => e
				tmp.delete?
				raise e
			end
		end

		# Links one's data to target data.
		def store_link(prefix, name, target)
			file= prefix_data_file(prefix, name)
			tmp= file.dirname + (file.basename.to_s + ".tmp")
			target= prefix_data_file(prefix, target)
			begin
				FileUilts.mv(file, tmp) if file.linkfile?
				file.make_symlink(target.basename)
				tmp.delete?
			rescue
				FileUilts.mv(tmp, file) if tmp.linkfile?
			end
		end

		# Removes a record.
		def remove(prefix, name)
			index= YAMLTools.read_array(prefix_reverse_file(prefix, name), String)
			begin
				index.each do |ind|
					remove_index(prefix, ind, name)
				end
				prefix_data_file(prefix, name).delete?
			rescue Exception => e
				index.each do |ind|
					store_index(prefix, ind, name)
				end
				raise e
			end
		end

		# Removes an index for a record.
		def remove_index(prefix, index, name)
			return unless self.index(prefix, index).include?(name)
			begin
				rm_index(prefix, index, name)
			rescue Exception => e
				add_index(prefix, index, name)
				raise e
			end
		end

		private
		
		def add_index(prefix, index, name)
			YAMLTools.change_array(prefix_index_file(prefix, index), String) do |a|
				a + [name]
			end
			YAMLTools.change_array(prefix_reverse_file(prefix, name), String) do |a|
				a + [index]
			end
		end

		def rm_index(prefix, index, name)
			YAMLTools.change_array(prefix_index_file(prefix, index), String) do |a|
				a - [name]
			end
			YAMLTools.change_array(prefix_reverse_file(prefix, name), String) do |a|
				a - [index]
			end
		end

		def prefix_data_file(prefix, name)
			prefix_data_dir(prefix) + name.dir_encode
		end

		def prefix_index_file(prefix, index)
			prefix_index_dir(prefix) + index.dir_encode
		end

		def prefix_reverse_file(prefix, name)
			prefix_reverse_dir(prefix) + name.dir_encode
		end

		def prefix_data_dir(prefix)
			dir= prefix_dir(prefix)+"data"
			dir.mkdir unless dir.directory?
			dir
		end

		def prefix_index_dir(prefix)
			dir= prefix_dir(prefix)+"index"
			dir.mkdir unless dir.directory?
			dir
		end

		def prefix_reverse_dir(prefix)
			dir= prefix_dir(prefix)+"reverse"
			dir.mkdir unless dir.directory?
			dir
		end

		def prefix_dir(prefix)
			dir= @dir+prefix.dir_encode
			dir.mkdir unless dir.directory?
			dir
		end

	end

end
