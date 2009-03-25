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

require "filehosting/string"
require "filehosting/yamltools"

require "fileutils"
require "pathname"

module FileHosting

	# The FileCache caches files and automaticly deletes them,
	# when they are outdated.
	class FileCache

		def initialize(dir)
			dir= Pathname.new(dir) unless Pathname === dir
			@filesdir= dir + "files"
			@tagsdir= dir + "tags"
			[@filesdir, @tagsdir].each do |dir|
				dir.mkpath unless dir.directory?
			end
		end

		# stores a file in the cache
		def store(name, data, tags)
			file= @filesdir + name.dir_encode
			file.delete if file.file?
			begin
				add_tags(tags, name)
				File.open(file, "w") do |f|
					f.write(data)
				end
			rescue Exception => e
				file.delete if file.file?
				delete_tags(tags, name)
				raise e
			end
		end

		# Reads a file from the cache. If the requested file
		# does not exist, it can be created with a block. The
		# block must return an Array of the following form
		# [data, [tag, ..., tag]]. If the file was created
		# the data is returned.
		def retrieve(name, io= false)
			file= @filesdir + name.dir_encode
			if file.file?
				file.read
			else
				return nil unless block_given?
				data, tags= yield
				return nil unless data
				store(name, data, tags)
				data
			end
		end

		# Deletes all file associated with this tag.
		def delete_for_tag(tag)
			tag_file= @tagsdir + tag.dir_encode
			error= nil
			YAMLTools.read_array(tag_file).each do |file|
				file= @filesdir + file.dir_encode
				begin
					file.delete if file.file?
				rescue Exception => e
					error= e
				end
			end
			raise error if error
			tag_file.delete
		end
		
		def add_tags(tags, name)
			tags.each do |tag|
				tag_file= @tagsdir + tag.dir_encode
				YAMLTools.change_array(tag_file, String) do |a|
					(a + [name]).uniq
				end
			end
		end
		def delete_tags(tags, name)
			tags.each do |tag|
				tag_file= @tagsdir + tag.dir_encode
				YAMLTools.change_array(tag_file, String) do |a|
					a - [name]
				end
			end
		end

	end

end

