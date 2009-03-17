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
require "filehosting/fileinfo"
require "filehosting/nosuchfileerror"
require "filehosting/fileexistserror"
require "filehosting/internaldatacorruptionerror"

require "pathname"
require "yaml"
require "digest/sha2"
require "filemagic"
require "fileutils"

module FileHosting

	# FileDataSource stores all data in the filesystem
	class FileDataSource < DataSource

		def initialize(storage)
			@filesdir= Pathname.new(storage)+"files"
			@metadatadir= Pathname.new(storage)+"metadata"
			@tagsdir= Pathname.new(storage)+"tags"
			[@filesdir, @metadatadir, @tagsdir].each do |dir|
				dir.mkdir unless dir.directory?
			end
		end

		def search_tags(tags)
			tags= tags.clone
			res= uuids_by_tag(tags.pop)
			tags.each do |tag|
				res&= uuids_by_tag(tag)
			end
			res.collect { |uuid| fileinfo(uuid) }
		end

		def search_tags_partial(tags)
			count= Hash.new(0)
			tags.each do |tag|
				uuids_by_tag(tag).each do |uuid|
					count[uuid]+= 1
				end
			end
			res= count.keys
			res.delete_if { |x| count[x] == tags.size }
			res.sort! { |a,b| count[b] <=> count[a] }
			res.collect { |uuid| fileinfo(uuid) }
		end

		def fileinfo(uuid)
			file= @metadatadir+uuid.to_s
			raise NoSuchFileError.new(uuid) unless file.file?
			begin
				res= YAML.load(file.read)
			rescue
				raise InternalDataCorruptionError
			end
			raise InternalDataCorruptionError unless FileInfo === res
			res
		end

		# get all files uuid with this tag
		def uuids_by_tag(tag)
			read_tag(tag).collect do |str|
				begin
					UUID.parse(str)
				rescue ArgumentError
					raise InternalDataCorruptionError
				end
			end
		end

		def add_file(fileinfo, file)
			mfile= @metadatadir + fileinfo.uuid.to_s
			raise FileExistsError(fileinfo.uuid) if mfile.exist?
			ffile= @filesdir + fileinfo.uuid.to_s
			raise FileExistsError(fileinfo.uuid) if ffile.exist?
			begin
				store_file(fileinfo, file)
				store_fileinfo(fileinfo)
				register_uuid_for_tags(fileinfo.uuid, fileinfo.tags)
			rescue Exception => e
				begin
					FileUtils.rm(ffile)
					FileUtils.rm(mfile)
					unregister_uuid_for_tags(fileinfo.uuid, fileinfo.tags)
				ensure
					raise e
				end
			end
		end

		def update_filedata(uuid, file)
			old= fileinfo(uuid)
			new= old.clone
			ffile= @filesdir + old.uuid.to_s
			tmp_file= @filesdir + (old.uuid.to_s + ".tmp")
			begin
				FileUtils.mv(ffile, tmp_file)
				store_file(new, file)
				store_fileinfo(new)
				FileUtils.rm(tmp_file)
			rescue Exception => e
				begin
					FileUtils.mv(tmp_file, ffile)
					store_fileinfo(old)
				ensure
					raise e
				end
			end
		end

		def update_fileinfo(fileinfo)
			old= self.fileinfo(fileinfo.uuid)
			begin
				unregister_uuid_for_tags(fileinfo.uuid, old.tags-fileinfo.tags)
				store_fileinfo(fileinfo)
				register_uuid_for_tags(fileinfo.uuid, fileinfo.tags-old.tags)
			rescue Exception => e
				begin
					register_uuid_for_tags(fileinfo.uuid, old.tags-fileinfo.tags)
					store_fileinfo(old)
					unregister_uuid_for_tags(fileinfo.uuid, fileinfo.tags-old.tags)
				ensure
					raise e
				end
			end
		end

		private

		def read_tag(tag)
			file= @tagsdir+tag.to_s
			return [] unless file.file?
			begin
				res= YAML.load(file.read)
			rescue
				raise InternalDataCorruptionError
			end
			raise InternalDataCorruptionError unless Array === res
			res.each do |s|
				raise InternalDataCorruptionError unless String === s
			end
			res
		end

		def register_uuid_for_tags(uuid, tags)
			tags.each do |tag|
				uuids= read_tag(tag)
				uuids<< uuid.to_s
				file= @tagsdir+tag.to_s
				File.open(file, "w") do |f|
					f.write(uuids.to_yaml)
				end
			end
		end

		def unregister_uuid_for_tags(uuid, tags)
			tags.each do |tag|
				uuids= read_tag(tag)
				uuids.delete(uuid.to_s)
				file= @tagsdir+tag.to_s
				File.open(file, "w") do |f|
					f.write(uuids.to_yaml)
				end
			end
		end

		# stores the file and updates the fileinfo
		def store_file(fileinfo, file)
			dest= @filesdir + fileinfo.uuid.to_s
			file= Pathname.new(file) if String === file
			case file
			when Pathname
				FileUtils.cp(file, dest)
			when IO
				raise "to be implemented"
			end
			fileinfo.size= file.size
			fileinfo.hash_type= "SHA-256"
			fileinfo.hash= Digest::SHA256.file(dest).to_s
			begin
				fm= FileMagic.new(FileMagic::MAGIC_MIME)
				fileinfo.mimetype= fm.file(dest.to_s).sub(/; .*?$/, "")
			ensure
				fm.close
			end
			fileinfo
		end

		# stores the fileinfo
		def store_fileinfo(fileinfo)
			mfile= @metadatadir + fileinfo.uuid.to_s
			File.open(mfile, "w") do |f|
				f.write(fileinfo.to_yaml)
			end
		end

	end

end

