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

require "filehosting/error"
require "filehosting/nosuchfileerror"
require "filehosting/internaldatacorruptionerror"
require "filehosting/fileexistserror"
require "filehosting/nosuchusererror"

require "uuidtools"
require "io2io"

module FileHosting

	class NetworkData
	
		attr_reader :size

		def initialize(io= nil)
			@io= io
			@size= Array.new
			@data= Array.new
			@error= nil
			@read= 0
			if io
				line= io.gets.strip
				if line=~ /^error(\/(.+?))?$/
					arg= io.gets.strip
					text= io.gets.strip
					handle_error($2, arg, text)
				end
				line.to_i.times do
					@size<< io.gets.to_i
				end
			end
		end

		def add_string(str)
			@size<< str.size
			@data<< str.clone
		end

		def add_io(io, size)
			@size<< size
			@data<< io
		end

		def add_error(error)
			@error= error
		end

		def read_string(i)
			return nil unless @size[i]
			case @data[i]
			when String
				@data[i]
			else
				if @io and @read == i
					@read+= 1
					@io.read(@size[i])
				else
					nil
				end
			end
		end

		def read_io(i)
			return nil unless @size[i]
			case @data[i]
			when IO
				@data[i]
			else
				if @io and @read == i
					@read+= 1
					@io
				else
					nil
				end
			end
		end

		def transmit(io)
			if @error
				transmit_error(io, error)
			else
				io.puts @size.size
				@size.each do |s|
					puts s
				end
				@size.size.times do |i|
					data= @data[i]
					case data
					when String
						io.print data
					when IO
						IO2IO.do(data, io, @size[i])
					else
						raise "Dont know how to transmit '#{data.class}'"
					end
				end
			end
		end

		def transmit_error(io, error)
			name= case @error
			when Error
				error.class.sub(/^[^:]+::/, "").downcase
			else
				"error"
			end
			arg= case error
			when NoSuchFileError
				error.uuid.to_s
			when FileExistsError
				error.uuid.to_s
			when NoSuchUserError
				error.user.to_s
			end
			text= error.to_s
			io.puts name
			io.puts arg
			io.puts text
		end

		def handle_error(error, arg, text)
			case error
			when "nosuchfile"
				begin
					uuid= UUID.parse(arg)
				rescue ArgumentError
					raise InternalDataCorruptionError
				end
				raise NoSuchFileError.new(uuid)
			when "internaldatacorruption"
				raise InternalDataCorruption
			when "fileexists"
				begin
					uuid= UUID.parse(arg)
				rescue ArgumentError
					raise InternalDataCorruptionError
				end
				raise FileExistsError.new(uuid)
			when "nosuchuser"
				raise NoSuchUserError(arg)
			else
				raise text
			end
		end

	end

end
