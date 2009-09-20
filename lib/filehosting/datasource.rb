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
require "filehosting/methodannouncing"
require "filehosting/fileinfo"
require "filehosting/rule"
require "filehosting/uuid"

require "observer"
require "thread"

autoload :Text, "text"

module FileHosting

	autoload :NoSuchUserError, "filehosting/nosuchusererror"
	autoload :InvalidRuleSetError , "filehosting/invalidruleseterror"
	autoload :UserAuthenticationError, "filehosting/userauthenticationerror"
	autoload :OperationNotPermittedError, "filehosting/operationnotpermittederror"

	class DataSourceCountStruct

		attr_accessor :ops
		attr_accessor :prepared_rules

		def initialize
			@ops= Hash.new(0)
			@prepared_rules= Hash.new
		end

	end

	# The DataSource knows everything
	class DataSource

		include Observable
		extend MethodAnnouncing

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

		# count all data which was read
		def count(&block)
			array= Thread.current[global_name]
			array= Thread.current[global_name]= [] unless array
			struct= DataSourceCountStruct.new
			array << struct
			block.call
			array.pop
			struct.ops.each do |op, num|
				array[-1].ops[op]+= num
			end if array[-1]
			struct.ops
		end

		# Returns an array of all valid rulesets
		def self.rulesets
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
			]
		end

		# The same for instances. This is necessary for
		# announce_method
		def rulesets
			self.class.rulesets
		end
		announce_method :rulesets

		# The following methods (except check_...) should be reimplemented in a
		# child class of DataSource.

		# Checks whether the user is forbidden to use any of
		# the methods: search_tags, search_tags_partial, and
		# files, with the arguments given.
		def check_search(tags, rule= nil)
			check_rule("search", {"tags" => tags})
		end
		announce_method :check_search, [String], [String, Rule]

		# searches for all files with these tags
		def search_tags(tags, rule= nil)
			check_raise(check_search(tags, rule), "search(#{tags.inspect})")
			register_op(tags.collect { |tag| "tags/#{tag}" } )
		end
		announce_method :search_tags, [[String]], [[String], Rule]

		# searches for all files with at least on of this tags
		def search_tags_partial(tags, rule=nil)
			check_raise(check_search(tags, rule), "search(#{tags.inspect})")
			register_op(tags.collect { |tag| "tags/#{tag}" } )
		end
		announce_method :search_tags_partial, [[String]], [[String], Rule]

		# returns fileinfo's for all files
		def files(rule= nil)
			check_raise(check_search(tags), "files()")
			register_op("files")
		end
		announce_method :files, [], [Rule]

		# Checks whether the user is forbidden to use any of
		# the methods: tags, tag_exists?, real_tags, real_tag,
		# taginfo.
		def check_tags
			check_rule("tags")
		end
		announce_method :check_tags

		# returns all available tags
		def tags
			check_raise(check_tags, "tags()")
			register_op("tags")
		end
		announce_method :tags

		# returns whether this tag exists
		def tag_exists?(tag)
			check_raise(check_tags, "tag_exists?(#{tag})")
			register_op("tags")
		end
		announce_method :tag_exists?, [String]

		# returns all tags which are not symlinks
		def real_tags
			check_raise(check_tags, "real_tags()")
			register_op("tags")
		end
		announce_method :real_tags

		# Checks whether the user is forbidden to use any of
		# the methods: set_tag_alias, and remove_tag_alias
		def check_tag_alias
			check_rule("tags_alias")
		end
		announce_method :check_tag_alias

		# sets a tag as an alias to another tag
		def set_tag_alias(tag, target)
			check_raise(check_tag_alias, "set_tag_alias(#{tag.inspect}, #{target.inspect})")
			notify_observers("tags")
			notify_observers("tags/#{tag}")
		end
		announce_method :set_tag_alias, [String, String]
		announce_sideeffect :set_tag_alias

		# removes a tag alias
		def remove_tag_alias(tag)
			check_raise(check_tag_alias, "remove_tag_alias(#{tag.inspect}")
			notify_observers("tags")
			notify_observers("tags/#{tag}")
		end
		announce_method :remove_tag_alias, [String]
		announce_sideeffect :remove_tag_alias

		# reads the target of a tag alias
		def tag_alias(tag)
			register_op("tags/#{tag}")
		end
		announce_method :tag_alias, [String]

		# returns infos about a tag
		def taginfo(tag)
			check_raise(check_tags, "taginfo(#{tag.inspect})")
			register_op("taginfo/#{tag}")
		end
		announce_method :taginfo, [String]

		# stores infos about a tag
		def set_taginfo(tag, info)
			check_raise(check_tags, "set_taginfo(#{tag.inspect}, #{info.inspect})")
			notify_observers("taginfo/#{tag}")
		end
		announce_method :set_taginfo, [String, String]
		announce_sideeffect :set_taginfo

		# Checks whether the user is forbidden to call the
		# method fileinfo with this argument.
		def check_fileinfo(uuid)
			fileinfo= read_fileinfo(uuid)
			check_rule("file", {}) or
			check_rule("file_withdata", {"file" => fileinfo}) or
			check_rule("file_info", {"file" => fileinfo})
		end
		announce_method :check_fileinfo, [UUID]

		# returns the fileinfo for the file with this uuid
		def read_fileinfo(uuid)
			register_op("files/#{uuid.uuid}")
		end
		protected :read_fileinfo

		# Checks whether the user is forbidden to call the
		# method filedata with this argument.
		def check_filedata(uuid)
			fileinfo= read_fileinfo(uuid)
			check_rule("file", {}) or
			check_rule("file_withdata", {"file" => fileinfo}) or
			check_rule("file_data", {"file" => fileinfo})
		end
		announce_method :check_filedata, [UUID]

		# returns the filedata
		def filedata(uuid, type= File)
			check_raise(check_filedata(uuid), "file_data(#{uuid.uuid.to_s})")
			register_op("files/#{uuid.uuid}")
		end
		announce_method :filedata, [UUID]

		# Checks whether the user is forbidden to call the
		# method add_file
		def check_add_file
			check_rule("file", {}) or
			check_rule("file_add", {})
		end
		announce_method :check_add_file

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
		announce_method :add_file, [FileInfo, IO]
		announce_sideeffect :add_file

		# Checks whether the user is forbidden to call the
		# method update_fileinfo for this uuid. If uuid is
		# given as a FileInfo, it must be the old fileinfo,
		# not the updated one.
		def check_update_fileinfo(uuid)
			oldinfo= read_fileinfo(uuid)
			check_rule("file", {}) or
			check_rule("file_withdata", {"file" => oldinfo}) or
			check_rule("file_update", {"file" => oldinfo})
		end
		announce_method :check_update_fileinfo, [UUID]

		# Changes the metadata of a file. There is no uuid
		# argument to specifiy which file is affected. This
		# information is read from the fileinfo.
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
		announce_method :update_fileinfo, [UUID]
		announce_sideeffect :update_fileinfo

		# Checks whether the user is forbidden to call the
		# method update_fileinfo for this uuid
		def check_update_filedata(uuid)
			fileinfo= self.read_fileinfo(uuid)
			check_rule("file", {}) or
			check_rule("file_withdata", {"file" => fileinfo}) or
			check_rule("file_replace", {"file" => fileinfo})
		end
		announce_method :check_update_filedata, [UUID]

		# Replaces a file, but not it's metadata.
		# Returns the fileinfo
		def update_filedata(uuid, file)
			check_raise(check_update_fileinfo(uuid), "file_replace(#{uuid.uuid})")
			notify_observers("files")
			notify_observers("files/#{uuid.uuid}")
		end
		announce_method :update_filedata, [UUID, IO]
		announce_sideeffect :update_filedata

		# Checks whether the user is forbidden to call the
		# method remove_file for this uuid.
		def check_remove_file(uuid)
			fileinfo= read_fileinfo(uuid)
			check_rule("file", {}) or
			check_rule("file_withdata", {"file" => fileinfo}) or
			check_rule("file_remove", {"file" => fileinfo})
		end
		announce_method :check_remove_file, [UUID]

		# removes a file
		def remove_file(uuid)
			fileinfo= read_fileinfo(uuid)
			check_raise(check_remove_file(fileinfo), "file_remove(#{fileinfo.uuid})")
			notify_observers("files")
			notify_observers("files/#{uuid}")
			fileinfo.tags.each do |tag|
				notify_observers("tags/#{tag}")
			end
			if fileinfo.tags.find { |tag| search_tags([tag]).size == 1 }
				notify_observers("tags")
			end
		end
		announce_method :remove_file, [UUID]
		announce_sideeffect :remove_file

		# Checks whether the user is forbidden to call the
		# method history_files with these arguments.
		def check_history_file(uuid, age= 1)
			fileinfo= read_fileinfo(uuid)
			check_rule("history",{"age" => age}) or
			check_rule("file", {}) or
			check_rule("file_withdata", {"file" => fileinfo}) or
			check_rule("history_file", {"file" => fileinfo, "age" => age})
		end
		announce_method :check_history_file, [UUID], [UUID, (1..(1.0/0))]

		# returns the history of a file
		def history_file(uuid, age= 1)
			check_raise(check_history_file(uuid, age), "history_user(#{uuid.uuid})")
			register_op("files/#{uuid.uuid}")
		end
		announce_method :history_file, [UUID], [UUID, (1..(1.0/0))]

		# Checks whether the user is forbidden to call the
		# method user for this username. The user is always
		# allowed to call user without any arguments.
		def check_user(username= nil)
			return false unless username
			user2= read_user(username)
			check_rule("user", {}) or
			check_rule("user_withdata", {"user2" => user2}) or
			check_rule("user_read", {"user2" => user2})
		end
		announce_method :check_user, [], [String]

		# returns information about a user
		def read_user(username)
			register_op("user/#{username.username}")
		end
		protected :read_user

		# Checks whether the user is allowed to call the
		# method add_user
		def check_add_user
			check_rule("user", {}) or
			check_rule("user_add", {})
		end
		announce_method :check_add_user

		# creates a new user
		def add_user(user2)
			if check_add_user or
			    check_rule("user_add_post", {"user2" => user2})
				raise OperationNotPermittedError.new("user_add(#{user2.username})")
			end
			notify_observers("user/#{user2.username}")
		end
		announce_method :add_user, [User]
		announce_sideeffect :add_user

		# Checks whether the user is allowed to call the
		# method update_user for this username
		def check_update_user(username)
			olduser= read_user(username)
			check_rule("user", {}) or
			check_rule("user_withdata", {"user2" => olduser}) or
			check_rule("user_update", {"user2" => olduser})
		end
		announce_method :check_update_user, [String]

		# Updates a user. The information which user to updat
		# is extracted from newuser
		def update_user(newuser, olduser= nil)
			olduser= olduser || read_user(newuser.username)
			if check_update_user(olduser) or
			   check_rule("user_update_post", {"newuser" => user, "user2" => olduser})
				raise OperationNotPermittedError.new("user_update(#{newuser.username})")
			end
			notify_observers("user/#{newuser.username}")
		end
		announce_method :update_user, [User]
		announce_sideeffect :update_user

		# Checks whether the user is allowed to call the
		# method history_user with these arguments
		def check_history_user(username= @user, age= 1)
			user2= read_user(username)
			check_rule("user", {"age" => age}) or
			check_rule("user_withdata", {"user2" => user2}) or
			check_rule("history") or
			check_rule("history_user", {"user2" => user2, "age" => age})
		end
		announce_method :check_history_user, [], [String], [String, (1..(1.0/0))]

		# returns the history of a user
		def history_user(username= @user, age= 1)
			check_raise(check_history_user(username, age), "history_user(#{username.username})")
			register_op("user/#{username.username}")
		end
		announce_method :history_user, [], [String], [String, (1..(1.0/0))]

		# Checks whether the user is allowed to call the
		# method rule for this ruleset
		def check_rules(ruleset)
			check_rule("rules", {"ruleset" => ruleset}) or
			check_rule("rules_read", {"ruleset" => ruleset})
		end
		announce_method :check_rules, [rulesets]

		# reads a rule set
		def read_rules(ruleset)
			register_op("rules/#{ruleset}")
		end
		protected :read_rules

		# Checks whether the user is allowed to call the
		# method add_rule for this ruleset
		def check_add_rule(ruleset)
			check_rule("rules", {"ruleset" => ruleset}) or
			check_rule("rules_add", {"ruleset" => ruleset})
		end
		announce_method :check_add_rule, [rulesets]

		# Adds a rule to a rule set. Position says on which
		# position in the ruleset to add the rule. 0 is before
		# the first rule. 1 is after the first rule. 2 is
		# after the second rule…
		def add_rule(ruleset, rule, position)
			raise InvalidRuleSetError.new(ruleset) unless ruleset_valid?(ruleset)
			if check_add_rule(ruleset) or
			   check_rule("rules_add_post", {"ruleset" => ruleset, "rule" => rule, "position" => position})
				raise OperationNotPermittedError.new("add_rule(#{ruleset.inspect})")
			end
			notify_observers("rules/#{ruleset}")
			notify_observers("rules")
		end
		announce_method :add_rule, [rulesets, Rule, (0..(1.0/0))]
		announce_sideeffect :add_rule

		# Checks whether the user is allowed to call the
		# method remove_rule for this ruleset
		def check_remove_rule(ruleset)
			check_rule("rules", {"ruleset" => ruleset}) or
			check_rule("rules_remove", {"ruleset" => ruleset})
		end
		announce_method :check_remove_rule, [rulesets]

		# removes a rule from a rule set
		def remove_rule(ruleset, rule)
			raise InvalidRuleSetError.new(ruleset) unless ruleset_valid?(ruleset)
			check_raise(check_remove_rule(ruleset), "remove_rule(#{ruleset.inspect}, #{rule.to_s})")
			notify_observers("rules/#{ruleset}")
			notify_observers("rules")
		end
		announce_method :remove_rule, [rulesets, Rule]
		announce_sideeffect :remove_rule

		# check if something is forbidden
		# returns true if it is forbidden
		# some rulesets need additional data to be evaluated
		def check_rule(ruleset, data= Hash.new)
			# root is allowed to do everything
			return nil if user.username == "root"
			# the count struct holds prepared rulesets
			struct= count_struct
			prepared_rule(ruleset).each do |rule|
				res= rule.test(data)
				return res unless res.nil?
			end
			return nil
		end
		protected :check_rule

		# returns a prepared rule
		# Some data like the user does not change. There is
		# no need to evaluate these kind of rules twice.
		def prepared_rule(ruleset)
			struct= count_struct
			# test wether the ruleset is prepared
			r= struct.prepared_rules[ruleset]
			return r if r
			rules= []
			read_rules(ruleset).find do |rule|
				res= rule.prepare({ "user" => @user })
				# we don't need rules with no
				# possible result
				next if res.result.nil?
				rules<< res
				res.conditions.size == 0
			end
			struct.prepared_rules[ruleset]= rules
		end
		protected :prepared_rule

		# Raises an operation not permidted error if the first
		# argument is true
		def check_raise(result, string)
			raise OperationNotPermittedError.new(string) if result
		end
		protected :check_raise

		# The following methods need not to be reimplemented
		# in a child class of DataSource.

		# returns the fileinfo for the file with this uuid
		def fileinfo(uuid)
			res= read_fileinfo(uuid)
			check_raise(check_fileinfo(res), "file_info(#{res.uuid.to_s})")
			res
		end
		announce_method :fileinfo, [UUID]


		# resolves tag aliases until a real tag is reached
		def real_tag(tag)
			check_raise(check_tags, "real_tag(#{tag.inspect})")
			res= tag
			while tag= tag_alias(tag)
				res= tag
			end
			res
		end
		announce_method :real_tag, [String]

		# Returns information about a user. Without any
		# arguments this returns the informations about the
		# calling user itself.
		def user(username= nil)
			unless username
				register_op("user/#{@user.username}")
				return @user
			end
			result= read_user(username)
			check_raise(check_user(result), "user_read(#{result.username})")
			return result
		end
		announce_method :user, [], [String]

		# reads a rule set
		def rules(ruleset)
			raise InvalidRuleSetError.new(ruleset) unless ruleset_valid?(ruleset)
			check_raise(check_rules(ruleset), "rulse(#{ruleset.inspect})")
			read_rules(ruleset)
		end
		announce_method :rules, [rulesets]

		# Guesses possible tags, which could be meant for a
		# given tag. The given tag does not need to be an
		# existing tag. Returns an array of all possibilities
		# sorted from most likely, to most unlikely.
		def guess_tag(tag)
			used= [tag]
			tags.collect do |x|
			# get all distances to this tag
				[did_you_mean_distance(tag, x), x]
			end.select do |distance, x|
			# only negative distances are used
				distance < 0
			end.sort do |a, b|
			# sort from most likely, to most unlikely
				a[0] <=> b[0]
			end.collect do |distacne, x|
			# return only the tag
				x
			end.reject do |x|
			# no tag should be twice in the list, this
			# could happen through tagaliases
				real= real_tag(x)
				if used.include?(real)
					true
				else
					used<< real
					false
				end
			end
		end
		announce_method :guess_tag, [String]

		# Computes the did you mean distance between two
		# strings. If the longest common subsequence (lcs)
		# contains adjacent characters which where adjacent in
		# the original strings, the distance will be lowered.
		# If between two in the lcs adjacent character, or the
		# beginning of the lcs and the first character, or the
		# last character of the lcs and the end of the string,
		# are other characters in the original strings, the
		# distance will be raised. This is computed for every
		# possible lcs (the lcs is not unique). The lowest
		# distance found for an lcs is taken as the original
		# strings distance.
		def did_you_mean_distance(a, b)
			a= a.downcase
			b= b.downcase
			lcs(a, b).collect do |lcs|
				res= 0
				(lcs.size-1).times do |i|
				# find all character which are
				# adjacent in the lcs and the original
				# strings
					res-= 2 if lcs[i][0]+1 == lcs[i+1][0] and lcs[i][1]+1 == lcs[i+1][1]
				end
				lcs2= [[-1, -1]] + lcs + [[a.size, b.size]]
				(lcs.size+1).times do |i|
				# calculate whether between two in the
				# lcs adjacent characters are
				# characters in the original strings
					u1= lcs2[i][0]+1 - lcs2[i+1][0]
					u2= lcs2[i][1]+1 - lcs2[i+1][1]
					res+= case
					when u1 == 0 && u2 == 0
					# no characters between
						0
					when u1 == 0 || u2 == 0
					# characters between in one
					# string
						1
					else
					# characters between in both
					# strings
						2
					end
				end
				res
			end.min
		end

		# Returns all possibilities for the lcs of the two
		# strings a and b. The lcs is returned as an array of
		# positions in both strings.
		# ex. "abc", "12b3" a possible lcs is "b" which will
		# be returned as [[1,2]] which means it consists of
		# the character which can be found at "abc"[1] and
		# "12b3[2]
		def lcs(a, b)
			# the lcs for a[0..i], "" is ""
			arr= Array.new(a.size + 1, [[]])
			1.upto(b.size) do |ii|
				tmp= [[]]
				1.upto(a.size) do |i|
				# calculate the lcs for a[0..i], b[0..ii]
					v= arr[i]
					case v[0].size <=> (arr[i-1][0].size)
					when -1
						v= arr[i-1]
					when 0
						v= (v + arr[i-1]).uniq
					end
					if a[i-1] == b[ii-1]
					# we found a common character
						case v[0].size <=> (tmp[0].size + 1)
						when -1
							v= tmp.collect { |ar| ar + [[i-1, ii-1]] }
						when 0
							v= (v + tmp.collect { |ar| ar + [[i-1, ii-1]] }).uniq
						end
					end
					tmp= arr[i]
					arr[i]= v
				end
			end
			arr[a.size]
		end

		# check if ruleset is a valid ruleset
		def self.ruleset_valid?(ruleset)
			rulesets.include?(ruleset)
		end

		def global_name
			:"FileHosting::DataSource?#{self.object_id}"
		end
		protected :global_name

		def count_struct
			array= Thread.current[global_name]
			array= Thread.current[global_name]= [] unless array
			array<< DataSourceCountStruct.new unless array[-1]
			array[-1]
		end

		def register_op(*op)
			struct= count_struct
			return unless struct
			hash= struct.ops
			op.flatten.each do |o|
				hash[o]+= 1
			end
		end

	end

end
