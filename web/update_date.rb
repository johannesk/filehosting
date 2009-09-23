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
	STDERR.puts "usage: ./update_date.rb <file> [file]..."
	exit 1
end

require "pathname"

$data= Pathname.new("data")
$date= Pathname.new("date")
$header= Pathname.new("header")


def update_date(file)
	datafile= $data+file
	datefile= $date+file
	headerfile= $header+file
	case
	when datafile.directory?
		headerfile.mkdir unless headerfile.directory?
		datafile.children.each do |child|
			update_date(child.relative_path_from($data))
		end
		puts file
	when datafile.symlink?
		unless headerfile.exist?
			headerfile.make_symlink(datafile.readlink)
			puts file
		end
	when datafile.file?
		headers= headerfile.read;
		headers=~ /Last-Modified:\s+([^\s][^\n]*)\n/
		olddate= $1
		newdate= datefile.read
		if olddate and olddate != newdate
			headers.sub!(/Last-Modified:\s+[^\s][^\n]*\n/, "Last-Modified: #{newdate}\n")
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
	update_date(Pathname.new(file))
end
