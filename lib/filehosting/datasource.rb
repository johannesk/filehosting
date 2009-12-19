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
require "filehosting/rule"
require "filehosting/typifieing"

require "observer"
require "filehosting/uuid"
autoload :Thread, "thread"

module FileHosting
	
	autoload :FileInfo, "filehosting/fileinfo"

	autoload :Algorithms, "filehosting/algorithms"
	autoload :ReadOnlyError, "filehosting/readonlyerror"
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

	class SpecialType

		attr_reader :type_name

		def initialize(type_name)
			@type_name= type_name
		end

	end

	# The DataSource knows everything
	class DataSource

		include Observable
		extend MethodAnnouncing

		@@needs_to_write= Hash.new(false)

		# marks the method as needing to write
		def self.needs_to_write(method= announced_last)
			raise "a non existing method can not need to write: #{method}" unless self.method_defined?(method)
			@@needs_to_write[method]= true
		end

		@@needs_rule= Hash.new { |h,k| h[k]= Hash.new }

		# Marks the method as gated by the given ruleset. If a
		# block is given, the block is responsible for
		# generating the ruleset data. If the method is
		# omitted, the last announced method is used.
		def self.needs_rule(method, ruleset= nil)
			unless ruleset
			# if only one argument is given, this is the
			# rule
				ruleset= method
				method= announced_last
			else
			# check if method exists?
				raise "a non existing method can not need a rule: #{method}" unless self.method_defined?(method)
			end

			# Check on validity of ruleset
			unless ruleset_valid?(ruleset)
				raise ArgumentError.new("no such ruleset: '#{ruleset}'")
			end

			@@needs_rule[method][ruleset]= if block_given?
				lambda { |*args| yield args }
			else
				true
			end
		end

		# Pretend can alway be called without an argument. If
		# no rule without arguments is specified, this call of
		# pretend will always return nil.
		@@pretend_args= Hash.new { |h, k| h[k]= [[]] }

		# Let pretend announce additional possible arguments
		# for the given method. If no method is given, the
		# last announced method is used. If no arguments are
		# given empty arguments are assumed.
		def self.pretend_args(method= nil, *args)
			# check if method is given
			if Array === method
				args.unshift(method)
				method= announced_last
			else
			# check if method exists?
				raise "a non existing method can not have arguments for pretend: #{method}" unless self.method_defined?(method)
			end
			
			# assume empty arguments if none given
			args= [[]] if args.size == 0

			@@pretend_args[method]= args
		end

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
				# create the user if it does not exist
				# yes (only for "root" and
				# "anonymous")
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

		# There are some special types:
		# - rulesets
		#     the rulesets can be read after the hash is
		#     finished building
		@@rulesets= {
			"search" => {},
			"search_post" => {"tags" => [String]},
			"search_filter" => {"file" => FileInfo},
			"tags" => {},
			"tags_write" => {},
			"rules" => {},
			"rules_withdata" => {"ruleset" => SpecialType.new(:rulesets)},
			"rules_read" => {"ruleset" => SpecialType.new(:rulesets)},
			"rules_add" => {"ruleset" => SpecialType.new(:rulesets)},
			"rules_add_post" => {"ruleset" => SpecialType.new(:rulesets), "rule" => Rule, "position" => (0..(1.0/0))},
			"rules_remove" => {"ruleset" => SpecialType.new(:rulesets)},
			"history" => {"age" => (0..(1.0/0))},
			"history_file" => {"age" => (0..(1.0/0)), "file" => FileInfo},
			"history_user" => {"age" => (0..(1.0/0)), "user2" => User },
			"user" => {},
			"user_withdata" => {"user2" => User },
			"user_read" => {"user2" => User },
			"user_add" => {},
			"user_add_post" => {"user2" => User },
			"user_update" => {"user2" => User},
			"user_update_post" => {"newuser" => User, "user2" => User},
			"file" => {},
			"file_withdata" => {"file" => FileInfo},
			"file_info" => {"file" => FileInfo},
			"file_data" => {"file" => FileInfo},
			"file_add" => {},
			"file_add_post" => {"file" => FileInfo},
			"file_update" => {"file" => FileInfo},
			"file_update_post" => {"newfile" => FileInfo, "file" => FileInfo},
			"file_replace" => {"file" => FileInfo},
			"file_remove" => {"file" => FileInfo},
		}
		# replace the special type rulesets with it's value
		@@rulesets.each do |x, hash|
			hash.keys.each do |key|
				if SpecialType === hash[key] and hash[key].type_name == :rulesets
					hash[key]= @@rulesets.keys
				end
			end
		end

		# Returns an array of all valid rulesets
		def self.rulesets
			@@rulesets.keys
		end

		# The same for instances. This is necessary for
		# announce_method
		def rulesets
			self.class.rulesets
		end
		announce_method :rulesets

		# check if ruleset is a valid ruleset
		def self.ruleset_valid?(ruleset)
			rulesets.include?(ruleset)
		end


		# The following methods should be reimplemented in a
		# child class of DataSource.

		# searches for all files with these tags
		# see search_finalize when reimplementing this method
		def search_tags(tags, rule= nil)
			correct_tags(tags)
			pretend_raise(:search_tags)
			register_op(tags.collect { |tag| "tags/#{tag}" } )
		end
		announce_method :search_tags, [[String]], [[String], Rule]
		needs_rule "search"
		needs_rule "search_post"

		# searches for all files with at least on of this tags
		# see search_finalize when reimplementing this method
		def search_tags_partial(tags, rule=nil)
			correct_tags(tags)
			pretend_raise(:search_tags_partial)
			register_op(tags.collect { |tag| "tags/#{tag}" } )
		end
		announce_method :search_tags_partial, [[String]], [[String], Rule]
		needs_rule "search"
		needs_rule "search_post"

		# returns fileinfo's for all files
		# see search_finalize when reimplementing this method
		def files(rule= nil)
			pretend_raise(:files)
			register_op("files")
		end
		announce_method :files, [], [Rule]
		needs_rule "search"
		needs_rule "search_post"

		# returns all available tags
		def tags
			pretend_raise(:tags)
			register_op("tags")
		end
		announce_method :tags
		needs_rule "tags"

		# returns whether this tag exists
		def tag_exists?(tag)
			pretend_raise(:tag_exists?)
			register_op("tags")
		end
		announce_method :tag_exists?, [String]
		needs_rule "tags"

		# returns all tags which are not symlinks
		def real_tags
			pretend_raise(:real_tags)
			register_op("tags")
		end
		announce_method :real_tags
		needs_rule "tags"

		# sets a tag as an alias to another tag
		def set_tag_alias(tag, target)
			pretend_raise(:set_tag_alias)
			notify_observers("tags")
			notify_observers("tags/#{tag}")
		end
		announce_method :set_tag_alias, [String, String]
		announce_sideeffect
		needs_to_write
		needs_rule "tags_write"

		# removes a tag alias
		def remove_tag_alias(tag)
			pretend_raise(:remove_tag_alias)
			notify_observers("tags")
			notify_observers("tags/#{tag}")
		end
		announce_method :remove_tag_alias, [String]
		announce_sideeffect
		needs_to_write
		needs_rule "tags_write"

		# reads the target of a tag alias
		def tag_alias(tag)
			pretend_raise(:tag_alias)
			register_op("tags/#{tag}")
		end
		announce_method :tag_alias, [String]
		needs_rule "tags"

		# returns infos about a tag
		def taginfo(tag)
			pretend_raise(:taginfo)
			register_op("taginfo/#{tag}")
		end
		announce_method :taginfo, [String]
		needs_rule "tags"

		# stores infos about a tag
		def set_taginfo(tag, info)
			pretend_raise(:set_taginfo)
			notify_observers("taginfo/#{tag}")
		end
		announce_method :set_taginfo, [String, String]
		announce_sideeffect :set_taginfo
		needs_to_write :set_taginfo
		needs_rule "tags_write"

		# returns the fileinfo for the file with this uuid
		def read_fileinfo(uuid)
			register_op("files/#{uuid.uuid}")
		end
		protected :read_fileinfo

		# returns the filedata
		def filedata(uuid, type= File)
			pretend_raise(:filedata, uuid)
			register_op("files/#{uuid.uuid}")
		end
		announce_method :filedata, [UUIDTools::UUID]
		needs_rule "file"
		needs_rule "file_withdata"
		needs_rule "file_data"

		# Adds a file to the datasource. There must be no
		# existing file with the same uuid. Some data from the
		# metadata will not be trusted and replaced by own
		# calculations (eg. filesize). File can ether be an IO
		# or a String. The IO will be read to EOF. The String
		# must contain the filename, from where to copy the
		# file.
		def add_file(fileinfo, file)
			pretend_raise(:add_file, fileinfo)
			correct_tags(fileinfo.tags)
			notify_observers("files")
			notify_observers("files/#{fileinfo.uuid}")
			fileinfo.tags.each do |tag|
				notify_observers("tags/#{tag}")
			end
			notify_observers("tags") unless (fileinfo.tags - tags).empty?
		end
		announce_method :add_file, [FileInfo, IO]
		pretend_args [FileInfo]
		announce_sideeffect
		needs_to_write
		needs_rule "file"
		needs_rule "file_add"
		needs_rule "file_add_post"

		# Changes the metadata of a file. There is no uuid
		# argument to specifiy which file is affected. This
		# information is read from the fileinfo.
		def update_fileinfo(fileinfo, oldinfo= nil)
			pretend_raise(:update_fileinfo, fileinfo, oldinfo)
			fileinfo.tags.collect! { |t| real_tag(t) }
			oldinfo= self.read_fileinfo(fileinfo.uuid) unless oldinfo
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
		announce_method :update_fileinfo, [UUIDTools::UUID]
		announce_sideeffect
		needs_to_write
		needs_rule "file"
		needs_rule("file_withdata") { |obj, *args| {"file" => args[1] || obj.read_fileinfo(args[0].uuid)} }
		needs_rule("file_update") { |obj, *args| {"file" => args[1] || obj.read_fileinfo(args[0].uuid)} }
		needs_rule("file_update_post") { |obj, *args| {"file" => args[1] || obj.read_fileinfo(args[0].uuid), "newfile" => args[0]} }

		# Replaces a file, but not it's metadata.
		# Returns the fileinfo
		def update_filedata(uuid, file)
			pretend_raise(:update_filedata, uuid)
			notify_observers("files")
			notify_observers("files/#{uuid.uuid}")
		end
		announce_method :update_filedata, [UUIDTools::UUID, IO]
		pretend_args [UUIDTools::UUID]
		announce_sideeffect
		needs_to_write
		needs_rule "file"
		needs_rule "file_withdata"
		needs_rule "file_replace"

		# removes a file
		def remove_file(uuid)
			pretend_raise(:remove_file, uuid)
			fileinfo= read_fileinfo(uuid)
			notify_observers("files")
			notify_observers("files/#{uuid}")
			fileinfo.tags.each do |tag|
				notify_observers("tags/#{tag}")
			end
			if fileinfo.tags.find { |tag| search_tags([tag]).size == 1 }
				notify_observers("tags")
			end
		end
		announce_method :remove_file, [UUIDTools::UUID]
		announce_sideeffect
		needs_to_write
		needs_rule "file"
		needs_rule "file_withdata"
		needs_rule "file_remove"

		# returns the history of a file
		def history_file(uuid, age= 1)
			pretend_raise(:history_file, uuid, age)
			register_op("files/#{uuid.uuid}")
		end
		announce_method :history_file, [UUIDTools::UUID], [UUIDTools::UUID, (1..(1.0/0))]
		needs_rule "history"
		needs_rule "file"
		needs_rule "file_withdata"
		needs_rule "history_file"

		# returns information about a user
		def read_user(username)
			register_op("user/#{username.username}")
		end
		protected :read_user

		# creates a new user
		def add_user(user2)
			pretend_raise(:add_user, user2)
			notify_observers("user/#{user2.username}")
		end
		announce_method :add_user, [User]
		announce_sideeffect :add_user
		needs_to_write :add_user
		needs_rule "user"
		needs_rule "user_add"
		needs_rule "user_add_post"

		# Updates a user. The information which user to update
		# is extracted from newuser
		def update_user(newuser, olduser= nil)
			pretend_raise(newuser, olduser)
			notify_observers("user/#{newuser.username}")
		end
		announce_method :update_user, [User]
		announce_sideeffect :update_user
		pretend_args :update_user, []
		needs_to_write :update_user
		needs_rule "user"
		needs_rule "user_withdata"
		needs_rule("user_update") { |obj, *args| {"user2" => args[1] || obj.read_fileinfo(args[0].uuid)} }
		needs_rule("user_update_post") { |obj, *args| {"user2" => args[1] || obj.read_fileinfo(args[0].uuid), "newuser" => args[0]} }

		# returns the history of a user
		def history_user(username, age= 1)
			pretend_raise(:history_user, username, age)
			register_op("user/#{username.username}")
		end
		announce_method :history_user, [], [String], [String, (1..(1.0/0))]
		needs_rule "user"
		needs_rule "user_withdata"
		needs_rule "history"
		needs_rule "history_user"

		# reads a rule set
		def read_rules(ruleset)
			register_op("rules/#{ruleset}")
		end
		protected :read_rules

		# Adds a rule to a rule set. Position says on which
		# position in the ruleset to add the rule. 0 is before
		# the first rule. 1 is after the first rule. 2 is
		# after the second rule…
		def add_rule(ruleset, rule, position)
			pretend_raise(:add_rule, ruleset, rule, position)
			raise InvalidRuleSetError.new(ruleset) unless self.class.ruleset_valid?(ruleset)
			notify_observers("rules/#{ruleset}")
			notify_observers("rules")
		end
		announce_method :add_rule, [rulesets, Rule, (0..(1.0/0))]
		pretend_args [rulesets]
		announce_sideeffect
		needs_to_write
		needs_rule "rules"
		needs_rule "rules_withdata"
		needs_rule "rules_add"
		needs_rule "rules_add_post"

		# removes a rule from a rule set
		def remove_rule(ruleset, rule)
			pretend_raise(ruleset, rule)
			raise InvalidRuleSetError.new(ruleset) unless self.class.ruleset_valid?(ruleset)
			notify_observers("rules/#{ruleset}")
			notify_observers("rules")
		end
		announce_method :remove_rule, [rulesets, Rule]
		pretend_args [rulesets]
		announce_sideeffect
		needs_to_write
		needs_rule "rules"
		needs_rule "rules_withdata"
		needs_rule "rules_remove"

		# The following methods need not to be reimplemented
		# in a child class of DataSource.

		# This should be called by search, search_partial and
		# files to generate the real result.
		def search_finalize(uuids, rule= nil)
			res= uuids.collect do |uuid|
				begin
					fileinfo(uuid)
				rescue OperationNotPermittedError
					nil
				end
			end.compact
			res= res.find_all { |info| !check_rule("search_filter", {"file" => info}) }
			res= res.find_all { |info| rule.test({"user" => @user, "file" => info}) } if rule
			res.sort { |a,b| (b.user_time || Time.now) <=> (a.user_time || Time.now) }
		end
		private :search_finalize

		# resolves tag aliases until a real tag is reached
		def real_tag(tag)
			pretend_raise(:real_tag)
			res= tag
			while tag= tag_alias(tag)
				res= tag
			end
			res
		end
		announce_method :real_tag, [String]
		needs_rule "tags"

		# Replaces tags inplace with the real tags.
		def correct_tags(tags)
			tags.collect! { |tag| real_tag(tag) }
		end

		# returns the fileinfo for the file with this uuid
		def fileinfo(uuid)
			pretend_raise(:fileinfo, uuid)
			res= read_fileinfo(uuid)
			res
		end
		announce_method :fileinfo, [UUIDTools::UUID]
		needs_rule "file"
		needs_rule "file_withdata"
		needs_rule "file_info"

		# Returns information about a user.
		def user(username)
			pretend_raise(:user, username)
			result= read_user(username)
			register_op("user/#{result.username}")
			return result
		end
		announce_method :user, [], [String]
		needs_rule "user"
		needs_rule "user_withdata"
		needs_rule "user_read"

		# Returns information about the calling user.
		def current_user
			register_op("user/#{@user.username}")
			@user
		end
		announce_method :current_user

		# reads a rule set
		def rules(ruleset)
			pretend_raise(:rules, ruleset)
			raise InvalidRuleSetError.new(ruleset) unless self.class.ruleset_valid?(ruleset)
			read_rules(ruleset)
		end
		announce_method :rules, [rulesets]
		needs_rule "rules"
		needs_rule "rules_withdata"
		needs_rule "rules_read"

		# Guesses possible tags, which could be meant for a
		# given tag. The given tag does not need to be an
		# existing tag. Returns an array of all possibilities
		# sorted from most likely, to most unlikely.
		def guess_tag(tag)
			used= [tag]
			tags.collect do |x|
			# get all distances to this tag
				[Algorithms::did_you_mean_distance(tag, x), x]
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
		needs_rule "tags"

		# check if something is forbidden
		# returns true if it is forbidden
		# some rulesets need additional data to be evaluated
		def check_rule(ruleset, data= Hash.new)
			# root is allowed to do everything
			return nil if current_user.username == "root"
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

		# Call pretend with the given arguments, and raises
		# the return value of pretend, if it is an error.
		def pretend_raise(method, *args)
			if error= pretend(method, *args)
				raise error
			end
		end
		protected :pretend_raise

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

		# Returns "method(arg1, arg2, ...)"
		def call_to_str(method, args)
			"#{method}(#{args.collect { |arg| arg.inspect }.join(", ")})"
		end

		public

		# Returns the Exception which would be raised if the
		# given method would be called with the given args. If
		# some of the args are omitted, only the rulesets
		# which don't need these arguments, are tested.
		def pretend(method, *args)
			method= method.to_sym

			# Test if method needs to write, but we are
			# read-only.
			if @config[:"read-only"] and @@needs_to_write[method]
				return ReadOnlyError.new(call_to_str(method, args))
			end

			# Test whether a gating ruleset objects to
			# this call.
			@@needs_rule[method].each do |rule, how|
				rule_args= case how
				when Proc
					how.call(self, *args)
				else
					begin
						Typifieing::scan_args(@@rulesets[rule], args)
					rescue ArgumentError
					# don't test this rule if
					# arguments are missing
						next
					end
				end
				if check_rule(rule, rule_args)
					return OperationNotPermittedError.new(call_to_str(method, args))
				end
			end
			nil
		end
		# this announcement must be made after all other announcements
		announce_method :pretend, *(announced_methods.collect { |method| (method_args(method) + @@pretend_args[method]).collect { |args| [method.to_s] + [args] } }.flatten(1))

	end

end
