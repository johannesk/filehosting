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

require "filehosting/user"
require "filehosting/uuid"

require "observer"
require "text"

module FileHosting

	autoload :NoSuchUserError, "filehosting/nosuchusererror"
	autoload :InvalidRuleSetError , "filehosting/invalidruleseterror"
	autoload :UserAuthenticationError, "filehosting/userauthenticationerror"
	autoload :OperationNotPermittedError, "filehosting/operationnotpermittederror"

	# The DataSource knows everything
	class DataSource

		include Observable

		def notify_observers(*arg)
			changed
			super
		end

		# You always have to specify a user
		def initialize(config)
			@config= config
			username= @config[:username]
			if ["anonymous", "root"].include?(username)
				begin
					user= read_user(username)
				rescue NoSuchUserError
					@user= User.new(username, "")
					add_user(@user)
					user= @user
				end
			else
				user= read_user(username)
			end
			raise UserAuthenticationError.new(username) unless user.check_password(@config[:password])
			@user= user
		end

		# The following methods (except check_...) should be reimplemented in a
		# child class of DataSource.

		def check_search(tags, rule= nil)
			check_rule("search", {"tags" => tags})
		end

		# searches for all files with these tags
		def search_tags(tags, rule= nil)
			check_raise(check_search(tags, rule), "search(#{tags.inspect})")
		end

		# searches for all files with at least on of this tags
		def search_tags_partial(tags, rule=nil)
			check_raise(check_search(tags, rule), "search(#{tags.inspect})")
		end

		# returns fileinfo's for all files
		def files
			check_raise(check_search(tags), "files()")
		end

		def check_tags
			check_rule("tags")
		end

		# returns all available tags
		def tags
			check_raise(check_tags, "tags()")
		end

		def check_tag_alias
			check_rule("tags_alias")
		end

		# sets a tag as an alias to another tag
		def set_tag_alias(tag, target)
			check_raise(check_tag_alias, "set_tag_alias(#{tag.inspect}, #{target.inspect})")
			notify_observers("tags")
		end

		# removes a tag alias
		def remove_tag_alias(tag)
			check_raise(check_tag_alias, "remove_tag_alias(#{tag.inspect}")
			notify_observers("tags")
		end

		# reads the target of a tag alias
		def tag_alias(tag)
			raise NotImplementedError
		end

		# resolves tag aliases until a real tag is reached
		def real_tag(tag)
			check_raise(check_tags, "real_tag(#{tag.inspect})")
			res= tag
			while tag= tag_alias(tag)
				res= tag
			end
			res
		end

		# returns infos about a tag
		def taginfo(tag)
			check_raise(check_tags, "taginfo(#{tag.inspect})")
		end

		# stores infos about a tag
		def set_taginfo(tag, info)
			check_raise(check_tags, "set_taginfo(#{tag.inspect}, #{info.inspect})")
			notify_observers("taginfo/#{tag}")
		end

		def check_fileinfo(uuid)
			fileinfo= read_fileinfo(uuid)
			check_rule("file", {}) or
			check_rule("file_withdata", {"file" => fileinfo}) or
			check_rule("file_info", {"file" => fileinfo})
		end

		# returns the fileinfo for the file with this uuid
		def fileinfo(uuid)
			res= read_fileinfo(uuid)
			check_raise(check_fileinfo(res), "file_info(#{res.uuid.to_s})")
			res
		end

		# returns the fileinfo for the file with this uuid
		def read_fileinfo(uuid)
			raise NotImplementedError
		end
		protected :read_fileinfo

		def check_filedata(uuid)
			fileinfo= read_fileinfo(uuid)
			check_rule("file", {}) or
			check_rule("file_withdata", {"file" => fileinfo}) or
			check_rule("file_data", {"file" => fileinfo})
		end

		# returns the filedata
		def filedata(uuid, type= File)
			check_raise(check_filedata(uuid), "file_data(#{uuid.uuid.to_s})")
		end

		def check_add_file
			check_rule("file", {}) or
			check_rule("file_add", {})
		end

		# Adds a file to the datasource. There must be no
		# existing file with the same uuid. Some data from the
		# metadata will not be trusted and replaced by own
		# calculations (eg. filesize). File can ether be an IO
		# or a String. The IO will be read to EOF. The String
		# must contain the filename, from where to copy the
		# file.
		def add_file(fileinfo, file)
			fileinfo.tags.collect! { |t| real_tag(t) }
			if check_add_file or
			   check_rule("file_add_post", {"file" => fileinfo})
				raise OperationNotPermittedError.new("file_add(#{fileinfo.uuid.to_s})")
			end
			notify_observers("files")
			notify_observers("files/#{fileinfo.uuid}")
			fileinfo.tags.each do |tag|
				notify_observers("tags/#{tag}")
			end
			notify_observers("tags") unless (fileinfo.tags - tags).empty?
		end

		def check_update_fileinfo(uuid)
			oldinfo= read_fileinfo(uuid)
			check_rule("file", {}) or
			check_rule("file_withdata", {"file" => oldinfo}) or
			check_rule("file_update", {"file" => oldinfo})
		end

		# Changes the metadata of a file
		def update_fileinfo(fileinfo, oldinfo= nil)
			fileinfo.tags.collect! { |t| real_tag(t) }
			oldinfo= self.read_fileinfo(fileinfo.uuid) unless oldinfo
			if check_update_fileinfo(oldinfo) or
			   check_rule("file_update_post", {"newfile" => fileinfo, "file" => oldinfo})
				raise OperationNotPermittedError.new("file_update(#{uuid})")
			end
			notify_observers("files")
			notify_observers("files/#{fileinfo.uuid}")
			new= fileinfo.tags
			old= oldinfo.tags
			plus= new - old
			minus= old - new
			(plus + minus).each do |tag|
				notify_observers("tags/#{tag}")
			end
			if not (plus - tags).empty? or minus.find { |tag| search_tags([tag]).size == 1 }
				notify_observers("tags")
			end
		end

		def check_update_filedata(uuid)
			fileinfo= self.read_fileinfo(uuid)
			check_rule("file", {}) or
			check_rule("file_withdata", {"file" => fileinfo}) or
			check_rule("file_replace", {"file" => fileinfo})
		end

		# Replaces a file, but not it's metadata.
		# Returns the fileinfo
		def update_filedata(uuid, file)
			check_raise(check_update_fileinfo(uuid), "file_replace(#{uuid.uuid})")
			notify_observers("files")
			notify_observers("files/#{uuid.uuid}")
		end

		def check_remove_file(uuid)
			fileinfo= read_fileinfo(uuid)
			check_rule("file", {}) or
			check_rule("file_withdata", {"file" => fileinfo}) or
			check_rule("file_remove", {"file" => fileinfo})
		end

		# removes a file
		def remove_file(uuid)
			fileinfo= read_fileinfo(uuid)
			check_raise(check_remove_file(fileinfo), "file_remove(#{fileinfo.uuid})")
			notify_observers("files")
			notify_observers("files/#{uuid}")
			if fileinfo.tags.find { |tag| search_tags([tag]).size == 1 }
				notify_observers("tags")
			end
		end

		def check_history_file(uuid, age= 1)
			fileinfo= read_fileinfo(uuid)
			check_rule("history",{"age" => age}) or
			check_rule("file", {}) or
			check_rule("file_withdata", {"file" => fileinfo}) or
			check_rule("history_file", {"file" => fileinfo, "age" => age})
		end

		# returns the history of a file
		def history_file(uuid, age= 1)
			check_raise(check_history_file(uuid, age), "history_user(#{uuid.uuid})")
		end

		def check_user(username)
			user2= read_user(username)
			check_rule("user", {}) or
			check_rule("user_withdata", {"user2" => user2}) or
			check_rule("user_read", {"user2" => user2})
		end

		# returns information about a user
		def user(username= nil)
			return @user unless username
			result= read_user(username)
			check_raise(check_user(result), "user_read(#{result.username})")
			return result
		end

		# returns information about a user
		def read_user(username)
			raise NotImplementedError
		end
		protected :read_user

		def check_add_user
			check_rule("user", {}) or
			check_rule("user_add", {})
		end

		# creates a new user
		def add_user(user2)
			if check_add_user or
			    check_rule("user_add_post", {"user2" => user2})
				raise OperationNotPermittedError.new("user_add(#{user2.username})")
			end
			notify_observers("user/#{user2.username}")
		end

		def check_update_user(username)
			olduser= read_user(username)
			check_rule("user", {}) or
			check_rule("user_withdata", {"user2" => olduser}) or
			check_rule("user_update", {"user2" => olduser})
		end

		# updates a user
		def update_user(newuser, olduser= nil)
			olduser= olduser || read_user(newuser.username)
			if check_update_user(olduser) or
			   check_rule("user_update_post", {"newuser" => user, "user2" => olduser})
				raise OperationNotPermittedError.new("user_update(#{newuser.username})")
			end
			notify_observers("user/#{newuser.username}")
		end

		def check_history_user(username= @user, age= 1)
			user2= read_user(username)
			check_rule("user", {"age" => age}) or
			check_rule("user_withdata", {"user2" => user2}) or
			check_rule("history") or
			check_rule("history_user", {"user2" => user2, "age" => age})
		end

		# returns the history of a user
		def history_user(username= @user, age= 1)
			check_raise(check_history_user(username, age), "history_user(#{username.username})")
		end

		def check_rules(ruleset)
			check_rule("rules", {"ruleset" => ruleset}) or
			check_rule("rules_read", {"ruleset" => ruleset})
		end

		# reads a rule set
		def rules(ruleset)
			raise InvalidRuleSetError.new(ruleset) unless ruleset_valid?(ruleset)
			check_raise(check_rules(ruleset), "rulse(#{ruleset.inspect})")
			read_rules(ruleset)
		end

		# reads a rule set
		def read_rules(ruleset)
			raise NotImplementedError
		end
		protected :read_rules

		def check_add_rule(ruleset)
			check_rule("rules", {"ruleset" => ruleset}) or
			check_rule("rules_add", {"ruleset" => ruleset})
		end

		# adds a rule to a rule set
		def add_rule(ruleset, rule, position)
			raise InvalidRuleSetError.new(ruleset) unless ruleset_valid?(ruleset)
			if check_add_rule(ruleset) or
			   check_rule("rules_add_post", {"ruleset" => ruleset, "rule" => rule, "position" => position})
				raise OperationNotPermittedError.new("add_rule(#{ruleset.inspect})")
			end
			notify_observers("rules/#{ruleset}")
			notify_observers("rules")
		end

		def check_remove_rule(ruleset, rule)
			check_rule("rules", {"ruleset" => ruleset}) or
			check_rule("rules_remove", {"ruleset" => ruleset, "rule" => rule})
		end

		# removes a rule from a rule set
		def remove_rule(ruleset, rule)
			raise InvalidRuleSetError.new(ruleset) unless ruleset_valid?(ruleset)
			check_raise(check_remove_rule(ruleset, rule), "remove_rule(#{ruleset.inspect}, #{rule.to_s})")
			notify_observers("rules/#{ruleset}")
			notify_observers("rules")
		end

		# check if something is allowed
		def check_rule(ruleset, data= Hash.new)
			data["user"]= @user
			return nil if data["user"].username == "root"
			read_rules(ruleset).each do |rule|
				res= rule.test(data)
				return res unless res.nil?
			end
			nil
		end
		protected :check_rule

		def check_raise(result, string)
			raise OperationNotPermittedError.new(string) if result
		end
		protected :check_raise

		# The following methods need not to be reimplemented
		# in a child class of DataSource.

		# Returns a better set of search tags
		def optimize_search(*search)
			search.flatten!
			search.uniq!
			available= tags
			(search-tags).each do |wrong|
				better= @config.cache.retrieve("search_optimize/"+wrong.dir_encode) do
					available.sort! { |a,b| (a.size-wrong.size).abs <=> (b.size-wrong.size).abs }
					found= nil
					min= 1.0/0
					s= 0
					catch :finished do
						available.each do |tag|
							throw :finished if (wrong.size - tag.size).abs > min
							r= Text::Levenshtein.distance(tag, wrong)
							n= (tag.split(//) & wrong.split(//)).size
							next if n == 0
							if r < min
								min= r
								found= tag
								s= 0
							elsif r == min
								if n > s
									s= n
									found= tag
								end
							end
						end
					end
					[found || "", ["tags"]]
				end
				search[search.index(wrong)]= better unless better.empty?
			end
			search.collect { |t| real_tag(t) }
		end

		# check if ruleset is a valid ruleset
		def ruleset_valid?(ruleset)
			[
				"search",
				"search_filter",
				"rules",
				"rules_read",
				"rules_add",
				"rules_add_post",
				"rules_remove",
				"history",
				"history_file",
				"history_user",
				"user",
				"user_withdata",
				"user_read",
				"user_add",
				"user_add_post",
				"user_update",
				"user_update_post",
				"file",
				"file_withdata",
				"file_info",
				"file_data",
				"file_add",
				"file_add_post",
				"file_update",
				"file_update_post",
				"file_replace",
				"file_remove",
			].include?(ruleset)
		end

	end

end
