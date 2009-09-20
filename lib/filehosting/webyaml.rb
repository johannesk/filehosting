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

require "filehosting/webpage"

require "uuidtools"

module FileHosting

	# This class allows rpc calls to config.datasource over the
	# web. Non FileHosting objects are transmitted as a folder in
	# the url. FileHosting objects are transmitted as yaml
	# documents in the http request.
	class WebYaml < WebPage

		# args are the url folders. io is the http body as an
		# IO object.
		#
		# FIXME add_file and update_filedata cannot be called
		def initialize(config, args, io)
			super(config)
			@header["Content-Type"]= "text/x-yaml"
			# We do handle our errors by ourself
			@error_handled= true
			# We are cachable unless the method called has
			# side effects
			@cachable= true
			if args.empty?
				@status= 404
				@body= "no method given"
				return
			end
			method= args.shift.to_sym
			# We are not cachable with side effects
			@cachable= false if config.datasource.class.sideeffect_announced?(method)
			unless config.datasource.class.method_announced?(method)
			# ensure only available methods can be called
				@status= 404
				@body= "no such method"
				return
			end

			# parse the args from the io
			begin
				YAML.each_document(io) do |doc|
					# Caching does not take the
					# http body in account. FIXME
					@cachable= false
					direction<< doc
				end
			rescue InternalDataCorruptionError
			# if it can not be parsed by yaml
				@status= 400
				@body= "invalid request body"
				@cachable= false
				return
			end

			args= self.class.parse_args(config.datasource.class.method_args(method), args)
			unless args
				@status= 400
				@body= "invalid args"
				return
			end
			@body= config.datasource.send(method, *args).to_yaml
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

