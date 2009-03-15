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

require "pathname"
require "yaml"
require "digest/sha2"
require "filemagic"

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
			return nil unless file.file?
			res= YAML.load(file.read)
			return nil unless FileInfo === res
			res
		end

		def register_uuid_for_tag(uuid, tag)
			uuids= uuids_by_tag(tag)
			uuids<< uuid.to_s
			file= @tagsdir+tag.to_s
			File.open(file, "w") do |f|
				f.write(uuids.to_yaml)
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

		def add_file(fileinfo, file)
			mfile= @metadatadir + fileinfo.uuid.to_s
			raise "uuid exists" if mfile.exist?
			store_file(fileinfo, file)
			File.open(mfile, "w") do |f|
				f.write(fileinfo.to_yaml)
			end
			fileinfo.tags.each do |tag|
				register_uuid_for_tag(fileinfo.uuid, tag)
			end
		end

		# get all files uuid with this tag
		def uuids_by_tag(tag)
			file= @tagsdir+tag.to_s
			return [] unless file.file?
			res= YAML.load(file.read)
			return [] unless Array === res
			res
		end

	end

end

