#!/usr/bin/ruby
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

if ARGV.size == 0
	STDERR.puts "usage: ./update_size.rb <file> [file]..."
	exit 1
end

require "pathname"

$data= Pathname.new("data")
$header= Pathname.new("header")


def update_size(file)
	datafile= $data+file
	headerfile= $header+file
	case
	when datafile.directory?
		headerfile.mkdir unless headerfile.directory?
		datafile.children.each do |child|
			update_size(child.relative_path_from($data))
		end
		puts file
	when datafile.symlink?
		unless headerfile.exist?
			headerfile.make_symlink(datafile.readlink)
			puts file
		end
	when datafile.file?
		headers= headerfile.read;
		headers=~ /Content-Length:\s+([1-9][0-9]*)\n/
		oldsize= $1.to_i
		newsize= datafile.size
		if oldsize and oldsize != newsize
			headers.sub!(/Content-Length:\s+[1-9][0-9]*\n/, "Content-Length: #{newsize}\n")
			File.open(headerfile, "w") do |f|
				f.puts headers
			end
			puts file
		end
	else
		STDERR.puts "file '#{file}' does not exist"
	end
end

ARGV.each do |file|
	update_size(Pathname.new(file))
end
