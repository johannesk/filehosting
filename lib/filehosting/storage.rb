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
		
		attr_reader :count_read
		attr_reader :count_write

		def initialize
			@count_read= 0
			@count_write= 0
		end

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

		# The following methods should be reimplemented by all
		# child classes of Storage.

		# Reads a record. Possible types are String, File and
		# IO.
		def read(prefix, name, type)
			@count_read+= 1
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
		def records_by_index(prefix, index)
			raise NotImplementedError
		end

		# Check whether records with this index exist.
		def index_exists?(prefix, index)
			raise NotImplementedError
		end

		# Searches all index's for a record or all records.
		def indexes_by_record(prefix, name= nil)
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
			@count_write+= 1
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

		# Removes an index for a record.
		def remove_index(prefix, index, name)
			raise NotImplementedError
		end

		def remove_data(prefix, name)
			raise NotImplementedError
		end

		# Tries to get a lock for the given arguments.
		# Constrains are addition resources to get a lock for.
		# Constrains is a block which returns
		# [file_r, index_r, file_w, index_w]. Constrains must
		# evaluated when ether the primary locks are already
		# in place, or the whole database is locked.
		# Returns whether the lock is in place.
		def get_lock(prefix, file_r, index_r,  file_w, index_w)
			raise NotImplementedError
		end
		protected :get_lock

		# Releases the locks for the given arguments.
		def release_lock(prefix, file_r, index_r, file_w, index_w)
			raise NotImplementedError
		end
		protected :release_lock

		# The following methods should not be reimplemented by
		# subclasses of Storage
		
		def global_name
			:"FileHosting::Storage?#{self.object_id}"
		end
		protected :global_name

		class LockStruct
			attr_accessor :global
			attr_accessor :local

			def initialize
				@global= false
				@local= [[], [], [], []]
			end
		end

		def lock_struct
			res= Thread.current[global_name]
			unless res
				res= LockStruct.new
				Thread.current[global_name]= res
			end
			res
		end
		protected :lock_struct
		
		# Locks files and indexes while executing the given
		# block. file_r, index_r, file_w, index_w are the
		# files and indexes to lock. If you need to lock files
		# without knowing in advanced which, you can use
		# constrains to specify these. Constrains must be a
		# block which returns
		# [file_r, index_r, file_w, index_w]. Constrains is
		# called every time trying to acquire a lock.
		def lock(prefix, file_r, index_r, file_w, index_w, constrains= nil ,&block)
			# we don't need to lock anything if we have a global lock
			if lock_struct.global
				return block.call
			end

			file_r= [file_r].flatten
			index_r= [index_r].flatten
			file_w= [file_w].flatten
			index_w= [index_w].flatten

			glocks= lock_struct.local

			# don't set locks twice
			file_w-= glocks[2]
			file_r-= file_w
			file_r-= glocks[2]
			file_r-= glocks[0]
			index_w-= glocks[3]
			index_r-= index_w
			index_r-= glocks[3]
			index_r-= glocks[1]
			cfr, cir, cfw, ciw= [], [], [], []

			begin
				loop do
					# check if lock can be
					# acquired
					if (!constrains and get_lock(prefix, file_r, index_r, file_w, index_w)) or
					(    constrains and get_lock(prefix, file_r, index_r, file_w, index_w) do
						lock_struct.global= true
						cfr, cir, cfw, ciw= constrains.call
						lock_struct.global= false
						cfw-= glocks[2]
						cfw-= file_w
						cfr-= cfw
						cfr-= file_w
						cfr-= glocks[2]
						cfr-= glocks[0]
						cfr-= file_r
						ciw-= glocks[3]
						ciw-= index_w
						cir-= ciw
						cir-= index_w
						cir-= glocks[3]
						cir-= glocks[1]
						cir-= index_r
						[cfr, cir, cfw, ciw]
					end)
						if glocks[0].size + glocks[1].size + glocks[2].size + glocks[3].size > 0 and
						    file_r.size+cfr.size+index_r.size+cir.size+file_w.size+cfw.size+index_w.size+ciw.size > 0
							STDERR.puts "You should avoid not to acquire all locks at the same time"
							STDERR.puts "already acquired: "#{glocks.inspet}"
							STDERR.puts "new locks: "#{[file_r + cfr, index_r + cir, file_w + cfw, index_w + ciw].inspect}"
						end
						glocks[0]+= file_r
						glocks[0]+= cfr
						glocks[1]+= index_r
						glocks[1]+= cir
						glocks[2]+= file_w
						glocks[2]+= cfw
						glocks[3]+= index_w
						glocks[3]+= ciw
						break
					else
						sleep 0.01
					end
				end

				# do the work
				res= block.call

			ensure
				# release the locks no matter what
				glocks[0]-= file_r
				glocks[0]-= cfr
				glocks[1]-= index_r
				glocks[1]-= cir
				glocks[2]-= file_w
				glocks[2]-= cfw
				glocks[3]-= index_w
				glocks[3]-= ciw
				release_lock(prefix, file_r + cfr, index_r + cir, file_w + cfw, index_w + ciw)
			end
			res
		end

		# Removes a record.
		def remove(prefix, name)
			index= nil
			lock(prefix, [], [], name, [], lambda do
				index= indexes_by_record(prefix, name)
				[[], [], [], index]
			end) do
				begin
					index.each do |ind|
						remove_index(prefix, ind, name)
					end
					remove_data(prefix, name)
				rescue Exception => e
					index.each do |ind|
						store_index(prefix, ind, name)
					end
					raise e
				end
			end
		end

		private

		def store_safe(prefix, name, index, date, &block)
			index= [index].flatten
			rev= nil
			plus= nil
			minus= nil
			lock(prefix, [], [], name, [], lambda do
				rev= indexes_by_record(prefix, name)
				plus= rev-index
				minus= rev - index
				[[], [], [], plus+minus]
			end) do
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

end
