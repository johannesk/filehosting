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
require "time"

require "io2io"

module FileHosting

	autoload :InternalDataCorruptionError, "filehosting/internaldatacorruptionerror"
	autoload :FileStorageVersionMismatchError, "filehosting/filestorageversionmismatcherror"

	# FileStorage implements a Storage, where all data is saved 
	# just in the filesystem.
	class FileStorage < Storage

		def self.version
			1
		end

		def initialize(dir)
			super()
			dir= Pathname.new(dir) unless Pathname === dir
			dir.mkpath unless dir.directory?
			versionfile= dir+".version"
			if dir.children.size == 0
			# this is a new storage
				# create version
				versionfile.open("w") { |f| f.write(self.class.version) }
			else
			# this is an existing storage
				# read version
				version= if versionfile.file?
					versionfile.read.to_i
				else
					0
				end
				# check for correct version
				unless version == self.class.version
					raise FileStorageVersionMismatchError.new(dir, self.class.version, version)
				end
			end
			@dir= dir
		end

		# Reads a record.
		def read(prefix, name, type= String)
			super(prefix, name, type)
			file= prefix_data_file(prefix, name)
			lock(prefix, name, [], [], []) do
				case
				when ! file.file?
					nil
				when type == String
					file.read
				when type == File
					file.open
				when type == IO
					file.open
				else
					raise NotImplementedError
				end
			end
		end

		# Reads the date of a record
		def date(prefix, name)
			file= prefix_date_file(prefix, name)
			lock(prefix, name, [], [], []) do
				res= if file.file?
					begin
						YAML.load(file.read)
					rescue
						InternalDataCorruptionError
					end
				else
					nil
				end
			end
			raise InternalDataCorruptionError unless res.nil? or Time === res
			res
		end

		# Checks whether a record exists.
		def exists?(prefix, name)
			file= prefix_data_file(prefix, name)
			lock(prefix, name, [], [], []) do
				file.file?
			end
		end

		# Searches all records for an index.
		def records_by_index(prefix, index)
			file= prefix_index_file(prefix, index)
			lock(prefix, [], index, [], []) do
				YAMLTools.read_array(file, String)
			end
		end

		# Check whether records with this index exists.
		def index_exists?(prefix, index)
			file= prefix_index_file(prefix, index)
			lock(prefix, [], index, [], []) do
				file.file?
			end
		end

		# Searches all index's for a record
		def indexes_by_record(prefix, name= nil)
			if name
				file= prefix_reverse_file(prefix, name)
				lock(prefix, name, [], [], []) do
					YAMLTools.read_array(file, String)
				end
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
			lock(prefix, [], [], name, index) do
				return if self.indexes_by_record(prefix, name).include?(index)
				begin
					add_index(prefix, index, name)
				rescue Exception => e
					rm_index(prefix, index, name)
					raise e
				end
			end
		end
		
		# Stores data.
		def store_data(prefix, name, data)
			super(prefix, name, data)
			file= prefix_data_file(prefix, name)
			tmp= file.dirname + (file.basename.to_s + ".tmp")
			data= [data].flatten
			lock(prefix, [], [], name, []) do
				begin
					if File === data[0]
						d= data.shift.path
						FileUtils.cp(d, tmp)
					end
					File.open(tmp, "a") do |f|
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
		end

		# Links one's data to target data.
		def store_link(prefix, name, target)
			file= prefix_data_file(prefix, name)
			tmp= file.dirname + (file.basename.to_s + ".tmp")
			target= prefix_data_file(prefix, target)
			lock(prefix, [], [], file, []) do
				begin
					FileUilts.mv(file, tmp) if file.linkfile?
					file.make_symlink(target.basename)
					tmp.delete?
				rescue
					FileUilts.mv(tmp, file) if tmp.linkfile?
				end
			end
		end

		# Set's the date of a record
		def set_date(prefix, name, date)
			file= prefix_date_file(prefix, name)
			lock(prefix, name, [], [], []) do
				File.open(file, "w") do |f|
					f.write(date.to_yaml)
				end
			end
		end

		# Removes the date of a record
		def remove_date(prefix, name)
			file= prefix_date_file(prefix, name)
			lock(prefix, name, [], [], []) do
				file.delete?
			end
		end

		# Removes an index for a record.
		def remove_index(prefix, index, name)
			lock(prefix, [], [], name, index) do
				return unless self.records_by_index(prefix, index).include?(name)
				begin
					rm_index(prefix, index, name)
				rescue Exception => e
					add_index(prefix, index, name)
					raise e
				end
			end
		end

		# Removes the data of a record
		def remove_data(prefix, name)
			prefix_data_file(prefix, name).delete?
		end

		protected

		# Tries to get a lock for the given arguments.
		# Constrains are addition resources to get a lock for.
		# Constrains is a block which returns
		# [file_r, index_r, file_w, index_w]. Constrains must
		# evaluated when ether the primary locks are already
		# in place, or the whole database is locked.
		# Returns whether the lock is in place.
		def get_lock(prefix, file_r, index_r,  file_w, index_w)
			read= prefix_lock_files(prefix, file_r, index_r)
			write= prefix_lock_files(prefix, file_w, index_w)

			lock_lock(prefix) do
				if block_given?
					cfr, cir, cfw, ciw= yield
					read+=  prefix_lock_files(prefix, cfr ,cir)
					write+= prefix_lock_files(prefix, cfw ,ciw)
				end

				# check if lock can be acquired
				if check_lock_files(read, write)
					false
				else
					get_lock_files(read, write)
				end
			end
		end

		# Releases the locks for the given arguments.
		def release_lock(prefix, file_r, index_r, file_w, index_w)
			read= prefix_lock_files(prefix, file_r, index_r)
			write= prefix_lock_files(prefix, file_w, index_w)

			lock_lock(prefix) do
				# release the locks
				release_lock_files(read, write)
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

		# locks the lockfile directory, so lockfiles can be
		# edited
		def lock_lock(prefix, &block)
			lockfile= prefix_lock_dir(prefix) + ".lock"
			# get the lock
			begin
				lockfile.open(File::CREAT | File::WRONLY | File::EXCL) do |f|
					f.print(Process.pid)
				end
			rescue Errno::EEXIST
				sleep 0.01
				retry
			end
			begin
			# do the work
				res= block.call
			# release the lock
			ensure
				lockfile.delete
			end
			res
		end

		# Checks whether these lock files are in place.
		def check_lock_files(read, write)
			write.any? do |file|
				# is read or write
				# locked?
				file.exist?
			end or read.any? do |dir|
				# is write locked?
				dir.file?
			end
		end

		# Creates the requested lock files
		def get_lock_files(read, write)
			write.each do |file|
				file.open("w") do |f|
					f.print(Process.pid)
				end
			end
			read.each do |dir|
				dir.mkdir?
				(dir + Process.pid.to_s).open("w") do |f|
				end
			end
		end

		# Releases the requested lock_files
		def release_lock_files(read, write)
			write.each do |file|
				file.delete?
			end
			read.each do |dir|
				if dir.directory?
					 (dir + Process.pid.to_s).delete?
					 # remove the read lock if no
					 # process needs it
					 dir.delete if dir.children.size == 0
				end
			end
		end
		
		def prefix_lock_files(prefix, files, indexes)
			res=  [files  ].flatten.collect { |file| prefix_lock_dir(prefix) + "file"  + file.to_s.dir_encode }
			res+= [indexes].flatten.collect { |file| prefix_lock_dir(prefix) + "index" + file.to_s.dir_encode }
			res
		end

		def prefix_data_file(prefix, name)
			prefix_data_dir(prefix) + name.dir_encode
		end

		def prefix_date_file(prefix, name)
			prefix_date_dir(prefix) + name.dir_encode
		end

		def prefix_index_file(prefix, index)
			prefix_index_dir(prefix) + index.dir_encode
		end

		def prefix_reverse_file(prefix, name)
			prefix_reverse_dir(prefix) + name.dir_encode
		end

		def prefix_data_dir(prefix)
			dir= prefix_dir(prefix)+"data"
			dir.mkdir?
			dir
		end

		def prefix_date_dir(prefix)
			dir= prefix_dir(prefix)+"date"
			dir.mkdir?
			dir
		end

		def prefix_index_dir(prefix)
			dir= prefix_dir(prefix)+"index"
			dir.mkdir?
			dir
		end

		def prefix_reverse_dir(prefix)
			dir= prefix_dir(prefix)+"reverse"
			dir.mkdir?
			dir
		end

		def prefix_lock_dir(prefix)
			dir= prefix_dir(prefix)+"lock"
			dir.mkdir?
			(dir + "file").mkdir?
			(dir + "index").mkdir?
			dir
		end

		def prefix_dir(prefix)
			dir= @dir+prefix.dir_encode
			dir.mkdir?
			dir
		end

	end

end
