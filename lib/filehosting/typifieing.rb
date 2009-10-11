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

require "filehosting/fileinfo"

require "uuidtools"

module FileHosting

	# A collection of methods for typifieing
	#
	# == Types
	#
	# The following types exist:
	# - Class: an object of this class
	# - [Class]: an array of objects of this class
	# - [a, b, c]: on of the members of this array
	# - (a..b): an object in this range.
	# - (Integer..Integer): if first or last in range is an integer the object must be an integer
	module Typifieing

		# Returns whether arg is of the type type.
		def self.matches_type?(arg, type)
			case type
			when String
			# "string"
				arg == type
			when Class
			# Class
				type === arg or
			# FileInfo
				type == UUID and FileInfo === arg
			when Array
				Array === arg and
				if type.size == 1
			# [type]
					arg.all? { |x| matches_type?(x, type[0]) }
				else
			# [type1, type2, ...]
					type.any? { |t| matches_type?(arg, t) }
				end
			when Range
				 if Integer === type.first or Integer === type.last
			# (1..10)
				 	Integer === arg
				else
			# (a..b)
					true
				end and
				begin
					type === arg
				rescue
				# in case of incompatible types in
				# type and arg
					false
				end
			else
				raise NotImplementedError
			end
		end

		# Searches the args for matching values. Pattern has
		# the following form: { var1 => type1, var2 => type2 }
		# Returns the following form:
		# { var1 => args[?], var2 => args[?] }
		def self.scan_args(pattern, args)
			res= Hash.new
			pattern.each do |key, type|
				arg= args.find { |arg| matches_type?(arg, type) }
				raise ArgumentError.new("No matching argument found") unless arg
				res[key]= arg
			end
			res
		end

		# Given multiple arg_sets and args in form of a
		# [String], returns one possible set of parsed args.
		def self.parse_args(arg_sets, args)
			# If we don't have args and the empty set is
			# possible take it
			return [] if args.size == 0 and arg_sets.include?([])

			# Only sets with size >= args are possible for
			# this request.
			arg_sets.delete_if { |set| set.size != args.size }

			remaining= Hash.new
			arg_sets.each_with_index do |set, i|
				remaining[i]= []
			end

			args.each_with_index do |raw, i|
				remaining.each do |set_i, args|
					# if this set is out
					next i if args.size > 0 and args[-1].nil?

					set= arg_sets[set_i]
					if FileHosting.constants.any? { |c| FileHosting.const_get(c) == set[i] }
					# FileHosting object have to be already parsed
						args<< if set[i] === raw
							raw
						end
					else
						args<< parse_as(set[i], raw)
					end
				end
			end

			# Find valid parsed args
			remaining.values.find { |args| !args[-1].nil? }
		end

		# Parses one symbol from an argset as specified in
		# MethodAnnouncing. Only a subset of the symbols in
		# the spec are supported. All symbols to parse
		# anything for use in DataSource are supported.
		# raw must be a string.
		def self.parse_as(type, raw)
			case
			when String === type
			# "something"
				raw if raw == type
			when String == type
			# String
				raw
			when Integer == type
			# Integer
				raw.to_i if raw=~ /^-?[1-9][0-9]*$/
			when Float == type
			# Float
				raw.to_f if raw=~ /^-?(0|[1-9][0-9]*)\.(0|[0-9]*[1-9])$/
			when UUID == type
			# UUID
				begin
					UUID.parse(raw)
				rescue ArgumentError
				end
			when Array === type && type.size == 1
			# [something]
				raw.split(/ +/).collect do |r|
					arg= parse_as(type[0], r)
					return nil unless arg
					arg
				end
			when Array === type
			# [23, 43]
				raw2= raw.split(/ +/)
				arg= (0..(type.size-1)).collect { |i| parse_as(type[i], raw2[i]) }
				arg if !arg.find { |x| x.nil? }
			when Range === type && [Integer, Float].any? { |c| c >= type.begin.class } && [Integer, Float].any? { |c| c >= type.end.class }
			# (23..42)
				arg= if Integer === type.begin or Integer === type.end
					parse_as(Integer, raw)
				else
					parse_as(Float, raw)
				end
				arg if type === arg
			end
		end

	end

end
