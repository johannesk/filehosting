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
require "filehosting/yamltools"
require "filehosting/user"

require "pathname"
require "yaml"
require "digest/sha2"
require "filemagic"
require "fileutils"
require "io2io"

module FileHosting

	autoload :NoSuchFileError, "filehosting/nosuchfileerror"
	autoload :FileExistsError, "filehosting/fileexistserror"
	autoload :NoSuchUserError, "filehosting/nosuchusererror"
	autoload :UserExistsError, "filehosting/userexistserror"
	autoload :InternalDataCorruptionError , "filehosting/internaldatacorruptionerror"

	# FileDataSource stores all data in the filesystem
	class StorageDataSource < DataSource

		def initialize(config)
			@storage= config.storage.prefix("datasource")
			super(config)
		end

		def search_tags(tags, rule= nil)
			tags= tags.clone
			res= uuids_by_tag(tags.pop)
			tags.each do |tag|
				res&= uuids_by_tag(tag)
			end
			res= res.collect { |uuid| fileinfo(uuid) }
			res= res.find_all { |info| rule.test({"fileinfo" => info}) } if rule
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
			@storage.reverse.grep(/^tag\//).collect { |r| tag_from_name(r) }
		end


		def fileinfo(uuid)
			data= @storage.read(fileinfo_name(uuid))
			raise NoSuchFileError.new(uuid) unless data
			begin
				res= YAML.load(data)
			rescue
				raise InternalDataCorruptionError
			end
			raise InternalDataCorruptionError unless FileInfo === res
			raise InternalDataCorruptionError unless res.uuid == uuid
			res
		end

		def filedata(uuid, type= File)
			data= @storage.read(filedata_name( uuid), type)
			raise NoSuchFileError.new(uuid) unless data
			data
		end

		# returns the history of a file
		def history_file(uuid)
			data= @storage.read(filehistory_name(uuid))
			raise NoSuchFileError.new(user) unless data
			YAMLTools.parse_array(data, HistoryEvent)
		end

		def add_file(fileinfo, file)
			super
			name= fileinfo_name(fileinfo)
			raise FileExistsError if @storage.exists?(name)
			index= fileinfo.tags.collect { |t| tag_name(t) }
			begin
				index.each do |ind|
					@storage.store_index(ind, name)
				end
				store_file(fileinfo, file)
			rescue Exception => e
				index.each do |ind|
					@storage.remove_index(ind, name)
				end
				raise e
			end
			store_history(:file_create, fileinfo.uuid.to_s, fileinfo.to_hash)
		end

		def update_filedata(uuid, file)
			super
			new= store_file(fileinfo(uuid), file)
			store_history(:file_replace, old.uuid.to_s, new-old)
			new
		end

		def update_fileinfo(fileinfo)
			super
			name= fileinfo_name(fileinfo)
			old= fileinfo(fileinfo.uuid)
			STDERR.puts "==="
			plus= (fileinfo.tags-old.tags).collect { |t| tag_name(t) }
			STDERR.puts plus
			STDERR.puts "---"
			minus= (old.tags-fileinfo.tags).collect { |t| tag_name(t) }
			STDERR.puts minus
			begin
				plus.each do |tag|
					@storage.store_index(tag, name)
				end
				@storage.store_data(name, fileinfo.to_yaml)
				minus.each do |tag|
					@storage.remove_index(tag, name)
				end
			rescue Exception => e
				begin
					minus.each do |tag|
						@storage.store_index(tag, name)
					end
					@storage.store_data(name, old.to_yaml)
					plus.each do |tag|
						@storage.remove_index(tag, name)
					end
				ensure
					raise e
				end
			end
			store_history(:file_update, old.uuid.to_s, fileinfo-old)
		end

		def remove_file(uuid)
			super
			old= fileinfo(uuid)
			name= fileinfo_name(old)
			index= @storage.reverse(name)
			begin
				@storage.remove(name)
				@storage.remove(filedata_name(uuid))
			rescue
				@storage.store(name, old.to_yaml, index)
			end
			store_history(:file_remove, old.uuid.to_s, Hash.new)
		end

		# returns information about a user
		def user(username= @user.username)
			name= user_name(username)
			raise NoSuchUserError.new(username) unless @storage.exists?(name)
			res= @storage.read(user_name(username))
			res= YAML.load(res)
			raise InternalDataCorruptionError unless User === res
			res
		end

		# creates a new user
		def add_user(user)
			name= user_name(user)
			raise UserExistsError.new(user.username) if @storage.exists?(name)
			@storage.store_data(name, user.to_yaml)
			store_history(:user_create, user.username, user.to_hash)
		end

		# updates a user
		def update_user(user)
			name= user_name(user)
			old= user(user.username)
			@storage.store_data(name, user.to_yaml)
			store_history(:user_update, user.username, user-old)
		end

		# removes a user
		def remove_user(username)
			name= user_name(user)
			raise NoSuchUserError unless @storage.exists?(name)
			@storage.remove(name)
			store_history(:user_remove, user.username, Hash.new)
		end

		# returns the history of a user
		def history_user(user= config.user)
			data= @storage.read(userhistory_name(user))
			raise NoSuchUserError.new(user) unless data
			YAMLTools.parse_array(data, HistoryEvent)
		end

		private

		# get all files uuid with this tag
		def uuids_by_tag(tag)
			@storage.index(tag_name(tag)).collect do |str|
				uuid_from_name(str)
			end
		end

		# stores the file and updates the fileinfo
		def store_file(fileinfo, file)
			filedata_name= filedata_name(fileinfo.uuid)
			fileinfo.hash_type= "SHA-256"
			tmp= false
			begin
				fm= FileMagic.new(FileMagic::MAGIC_MIME)
				case file
				when String
					fileinfo.size= file.size
					fileinfo.hash= Digest::SHA256.hexdigest(file)
					fileinfo.mimetype= fm.buffer(file).sub(/; .*?$/, "")
				when IO
					if !(File === file)
						tmp= true
						begin
							f= File.mktemp
							IO2IO.do(file, f)
						ensure
							f.close
						end
						file= f
					end
					fileinfo.size= File.size(tmpfile.path)
					fileinfo.hash= Digest::SHA256.file(tmpfile.path).to_s
					fileinfo.mimetype= fm.file(tmpfile.path).sub(/; .*?$/, "")
				else
					raise NotImplementedError
				end
				old= @storage.read(fileinfo_name(fileinfo))
				begin
					@storage.store_data(fileinfo_name(fileinfo), fileinfo.to_yaml)
					@storage.store_data(filedata_name, file)
				rescue Exception => e
					@storage.store_data(old.to_yaml) if old
					raise e
				end
			ensure
				FileUtils.rm(tmpfile.path) if tmp
				fm.close
			end
			fileinfo
		end

		def store_history(action, entity, data)
			event= HistoryEvent.new(@user.username, action, entity, data)
			fhistory_name= case action.to_s
			when /^file/
				data.delete(:uuid)
				filehistory_name(entity)
			when /^user/
				data.delete(:username)
				userhistory_name(entity)
			end
			uhistory_name= userhistory_name(event.user)
			history= YAMLTools.parse_array(@storage.read(history_name), HistoryEvent)
			fhistory= YAMLTools.parse_array(@storage.read(fhistory_name), HistoryEvent)
			uhistory= YAMLTools.parse_array(@storage.read(uhistory_name), HistoryEvent)
			history<< event
			fhistory<< event
			uhistory<< event
			@storage.store_data(history_name, history.to_yaml)
			@storage.store_data(fhistory_name, fhistory.to_yaml)
			@storage.store_data(uhistory_name, uhistory.to_yaml)
		end

		def fileinfo_name(fileinfo)
			case fileinfo
			when FileInfo
				"fileinfo/" + fileinfo.uuid.to_s
			when UUID
				"fileinfo/" + fileinfo.to_s
			end
		end

		def filedata_name(uuid)
			"filedata/" + uuid.to_s
		end

		def filehistory_name(uuid)
			"filehistory/" + uuid.to_s
		end

		def userhistory_name(user)
			"filehistory/" + user.to_s
		end

		def history_name
			"history"
		end

		def tag_name(tag)
			"tag/" + tag.to_s
		end

		def user_name(user)
			case user
			when String
				"user/" + user
			when User
				"user/" + user.username
			end
		end

		def uuid_from_name(name)
			begin
				UUID.parse(tag_from_name(name))
			rescue ArgumentError
				raise InternalDataCorruptionError
			end
		end

		def tag_from_name(name)
			raise InternalDataCorruption unless name=~ /^\w+\/(.+?)$/
			$1
		end

	end

end
