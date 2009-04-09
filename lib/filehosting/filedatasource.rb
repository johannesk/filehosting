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
require "filehosting/historyevent"
require "filehosting/nosuchfileerror"
require "filehosting/nosuchusererror"
require "filehosting/fileexistserror"
require "filehosting/internaldatacorruptionerror"
require "filehosting/yamltools"

require "pathname"
require "yaml"
require "digest/sha2"
require "filemagic"
require "fileutils"
require "io2io"

module FileHosting

	# FileDataSource stores all data in the filesystem
	class FileDataSource < DataSource

		def initialize(user, storage)
			super(user)
			@filesdir= Pathname.new(storage)+"files"
			@metadatadir= Pathname.new(storage)+"metadata"
			@tagsdir= Pathname.new(storage)+"tags"
			@historyfile= Pathname.new(storage)+"history"
			@filehistorydir= Pathname.new(storage)+"filehistory"
			@userhistorydir= Pathname.new(storage)+"userhistory"
			[@filesdir, @metadatadir, @tagsdir, @filehistorydir, @userhistorydir].each do |dir|
				dir.mkpath unless dir.directory?
			end
		end

		def search_tags(tags, rule= nil)
			tags= tags.clone
			res= uuids_by_tag(tags.pop)
			tags.each do |tag|
				res&= uuids_by_tag(tag)
			end
			res= res.collect { |uuid| fileinfo(uuid) }
			res= res.find_all { |info| rule.test({:fileinfo => info}) } if rule
			res
		end

		def search_tags_partial(tags, rule= nil)
			count= Hash.new(0)
			tags.each do |tag|
				uuids_by_tag(tag).each do |uuid|
					count[uuid]+= 1
				end
			end
			res= count.keys
			res.delete_if { |x| count[x] == tags.size }
			res.sort! { |a,b| count[b] <=> count[a] }
			res= res.collect { |uuid| fileinfo(uuid) }
			res= res.find_all { |info| rule.test({:fileinfo => info}) } if rule
			res
		end

		# returns all available tags
		def tags
			@tagsdir.children.collect do |child|
				child.basename.to_s.dir_decode
			end
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
			raise InternalDataCorruptionError unless res.uuid == uuid
			res
		end

		def filedata_string(uuid)
			file= @filesdir+uuid.to_s
			raise NoSuchFileError.new(uuid) unless file.file?
			file.to_s
		end

		# returns the history of a user
		def history_user(user= config.user)
			file= @userhistorydir + user.to_s
			raise NoSuchUserError.new(user) unless file.file?
			YAMLTools.read_array(file, HistoryEvent)
		end

		# returns the history of a file
		def history_file(uuid)
			file= @filehistorydir + uuid.to_s
			raise NoSuchFileError.new(uuid) unless file.file?
			YAMLTools.read_array(file, HistoryEvent)
		end

		def add_file(fileinfo, file)
			super
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
					remove_filedata(fileinfo.uuid)
					remove_fileinfo(fileinfo.uuid)
					unregister_uuid_for_tags(fileinfo.uuid, fileinfo.tags)
				ensure
					raise e
				end
			end
			store_history(:create, fileinfo.uuid, fileinfo.to_hash)
		end

		def update_filedata(uuid, file)
			super
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
			store_history(:replace, old.uuid, new-old)
			new
		end

		def update_fileinfo(fileinfo)
			super
			old= fileinfo(fileinfo.uuid)
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
			store_history(:update, old.uuid, fileinfo-old)
		end

		def remove_file(uuid)
			super
			old= fileinfo(uuid)
			begin
				unregister_uuid_for_tags(uuid, old.tags)
				remove_fileinfo(uuid)
				remove_filedata(uuid)
			rescue Exception => e
				begin
					register_uuid_for_tags(uuid, old.tags)
					store_fileinfo(old)
				ensure
					raise e
				end
			end
			store_history(:remove, old.uuid, Hash.new)
		end

		def remove_fileinfo(uuid)
			file= @metadatadir + uuid.to_s
			FileUtils.rm(file)
		end

		def remove_filedata(uuid)
			file= @filesdir + uuid.to_s
			FileUtils.rm(file)
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

		def read_tag(tag)
			YAMLTools.read_array(@tagsdir+tag.to_s, String)
		end

		def register_uuid_for_tags(uuid, tags)
			tags.each do |tag|
				uuids= read_tag(tag)
				uuids<< uuid.to_s
				file= @tagsdir+tag.to_s
				YAMLTools.store(file, uuids)
			end
		end

		def unregister_uuid_for_tags(uuid, tags)
			tags.each do |tag|
				uuids= read_tag(tag)
				uuids.delete(uuid.to_s)
				file= @tagsdir+tag.to_s
				if uuids.size > 0
					YAMLTools.store(file, uuids)
				else
					FileUtils.rm(file)
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
				File.new(dest, "w") do |f|
					IO2IO.do(file, dest)
				end
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
			YAMLTools.store(mfile, fileinfo)
		end

		def store_history(action, uuid, data)
			data.delete(:uuid) # we store the uuid separate
			event= HistoryEvent.new(@config.user, action, uuid, data)
			file= @historyfile
			ffile= @filehistorydir + event.uuid.to_s
			ufile= @userhistorydir + event.user.to_s
			history= YAMLTools.read_array(file, HistoryEvent)
			fhistory= YAMLTools.read_array(ffile, HistoryEvent)
			uhistory= YAMLTools.read_array(ufile, HistoryEvent)
			history<< event
			fhistory<< event
			uhistory<< event
			YAMLTools.store(file, history)
			YAMLTools.store(ffile, fhistory)
			YAMLTools.store(ufile, uhistory)
		end

	end

end

