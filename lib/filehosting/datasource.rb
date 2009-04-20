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

require "observer"
require "text"

module FileHosting

	autoload :NoSuchUserError, "filehosting/nosuchusererror"
	autoload :UserAuthenticationError, "filehosting/userauthenticationerror"
	autoload :InvalidRuleSetError , "filehosting/invalidruleseterror"

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
				user= user_add(username)
			end
			raise UserAuthenticationError.new(username) unless user.check_password(@config[:password])
			@user= user
		end

		# The following methods should be reimplemented in a
		# child class of DataSource.

		# searches for all files with these tags
		def search_tags(tags, rule= nil)
			if check_rule("search", {"tags" => tags})
				raise OperationNotPermitedError.new("search(#{tags.inspect})")
			end
		end

		# searches for all files with at least on of this tags
		def search_tags_partial(tags, rule=nil)
			if check_rule("search", {"tags" => tags})
				raise OperationNotPermitedError.new("search_partial(#{tags.inspect})")
			end
		end

		# returns all available tags
		def tags
			if check_rule("tags")
				raise OperationNotPermitedError.new("tags()")
			end
		end

		# returns the fileinfo for the file with this uuid
		def fileinfo(uuid)
			res= read_fileinfo(uuid)
			if check_rule("file", {"file" => res}) or
			   check_rule("file_info", {"file" => res})
				raise OperationNotPermitedError.new("file_info(#{uuid.to_s})")
			end
			res
		end

		# returns the fileinfo for the file with this uuid
		def read_fileinfo(uuid)
			raise NotImplementedError
		end
		protected :read_fileinfo

		# returns the filedata
		def filedata(uuid, type= File)
			fileinfo= read_fileinfo(uuid)
			if check_rule("file", {"file" => fileinfo}) or
			   check_rule("file_data", {"file" => fileinfo})
				raise OperationNotPermitedError.new("file_data(#{uuid.to_s})")
			end
		end

		# Adds a file to the datasource. There must be no
		# existing file with the same uuid. Some data from the
		# metadata will not be trusted and replaced by own
		# calculations (eg. filesize). File can ether be an IO
		# or a String. The IO will be read to EOF. The String
		# must contain the filename, from where to copy the
		# file.
		def add_file(fileinfo, file)
			if check_rule("file", {"file" => fileinfo}) or
			   check_rule("file_add", {"file" => fileinfo})
				raise OperationNotPermitedError.new("file_add(#{fileinfo.uuid.to_s})")
			end
			notify_observers("files/#{fileinfo.uuid}")
			fileinfo.tags.each do |tag|
				notify_observers("tags/#{tag}")
			end
			notify_observers("tags") unless (fileinfo.tags - tags).empty?
		end

		# Changes the metadata of a file
		def update_fileinfo(fileinfo)
			oldinfo= self.fileinfo(fileinfo.uuid)
			if check_rule("file", {"file" => oldinfo}) or
			   check_rule("file_update", {"newfile" => fileinfo, "file" => oldinfo})
				raise OperationNotPermitedError.new("file_update(#{fileinfo.uuid.to_s})")
			end
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

		# Replaces a file, but not it's metadata.
		# Returns the fileinfo
		def update_filedata(uuid, file)
			fileinfo= read_fileinfo(uuid)
			if check_rule("file", {"file" => fileinfo}) or
			   check_rule("file_replace", {"file" => fileinfo})
				raise OperationNotPermitedError.new("file_replace(#{uuid.to_s})")
			end
			notify_observers("files/#{uuid}")
		end

		# removes a file
		def remove_file(uuid)
			fileinfo= read_fileinfo(uuid)
			if check_rule("file", {"file" => fileinfo}) or
			   check_rule("file_remove", {"file" => fileinfo})
				raise OperationNotPermitedError.new("file_remove(#{uuid.to_s})")
			end
			notify_observers("files/#{uuid}")
			tags= read_fileinfo(uuid).tags
			if tags.find { |tag| search_tags([tag]).size == 1 }
				notify_observers("tags")
			end
		end

		# returns the history of a file
		def history_file(uuid)
			fileinfo= read_fileinfo(uuid)
			if check_rule("history") or
			   check_rule("file", {"file" => fileinfo}) or
			   check_rule("history_file", {"file" => fileinfo})
				raise OperationNotPermitedError.new("history_user(#{uuid.to_s})")
			end
		end

		# returns information about a user
		def user(username= @user.username)
			result= read_user(username)
			if check_rule("user", {"user2" => result}) or
			   check_rule("user_read", {"user2" => result})
				raise OperationNotPermitedError.new("user_read(#{username})")
			end
			return result
		end

		# returns information about a user
		def read_user(username)
			raise NotImplementedError
		end
		protected :read_user

		# creates a new user
		def add_user(user)
			if check_rule("user", {"user2" => user}) or
			   check_rule("user_add", {"user2" => user})
				raise OperationNotPermitedError.new("user_add(#{user.username})")
			end
			notify_observer("user/#{user.username}")
		end

		# updates a user
		def update_user(user)
			old= read_user(user.username)
			if check_rule("user", {"user2" => old}) or
			   check_rule("user_update", {"newuser" => user, "user2" => old})
				raise OperationNotPermitedError.new("user_update(#{user.username})")
			end
			notify_observer("user/#{user.username}")
		end

		# returns the history of a user
		def history_user(username= @user.username)
			user= read_user(username)
			if check_rule("user", {"username" => user.username}) or
			   check_rule("history") or
			   check_rule("history_user", {"user2" => user})
				raise OperationNotPermitedError.new("history_user(#{user.username})")
			end
		end

		# reads a rule set
		def rules(ruleset)
			raise InvalidRuleSetError.new(ruleset) unless ruleset_valid?(ruleset)
			if check_rule("rules", {"ruleset" => ruleset}) or
			   check_rule("rules_read", {"ruleset" => ruleset})
				raise OperationNotPermitedError.new("rules(#{ruleset.inspect})")
			end
			read_rules(ruleset)
		end

		# reads a rule set
		def read_rules(ruleset)
			raise NotImplementedError
		end
		protected :read_rules

		# adds a rule to a rule set
		def add_rule(ruleset, rule, position)
			raise InvalidRuleSetError.new(ruleset) unless ruleset_valid?(ruleset)
			if check_rule("rules", {"ruleset" => ruleset}) or
			   check_rule("rules_add", {"ruleset" => ruleset, "rule" => rule, "position" => position})
				raise OperationNotPermitedError.new("add_rule(#{ruleset.inspect})")
			end
			notify_observer("rules/#{ruleset}")
		end

		# removes a rule from a rule set
		def remove_rule(ruleset, rule)
			raise InvalidRuleSetError.new(ruleset) unless ruleset_valid?(ruleset)
			if check_rule("rules", {"ruleset" => ruleset}) or
			   check_rule("rules_remove", {"ruleset" => ruleset, "rule" => rule})
				raise OperationNotPermitedError.new("remove_rule(#{ruleset.inspect})")
			end
			notify_observer("rules/#{ruleset}")
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
			search
		end

		# check if ruleset is a valid ruleset
		def ruleset_valid?(ruleset)
			[
				"search",
				"search_filter",
				"rules",
				"rules_read",
				"rules_add",
				"rules_remove",
				"history",
				"history_file",
				"history_user",
				"user",
				"user_read",
				"user_add",
				"user_update",
				"file",
				"file_info",
				"file_data",
				"file_add",
				"file_update",
				"file_replace",
			].include?(ruleset)
		end

	end

end

