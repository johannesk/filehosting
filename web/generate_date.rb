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
	STDERR.puts "usage: ./generate_date.rb <file> [file]..."
	exit 1
end

require "pathname"
require "time"

$data= Pathname.new("data")
$date= Pathname.new("date")
time= Time.now.httpdate
$time= Pathname.new(time)
File.open($time, "w") do |f|
	f.write(time)
end

def generate_date(file)
	datafile= $data+file
	datefile= $date+file
	case
	when datafile.directory?
		datefile.mkdir unless datefile.directory?
		datafile.children.each do |child|
			generate_date(child.relative_path_from($data))
		end
		puts file
	when datefile.exist?
		return
	when datafile.symlink?
		datefile.make_symlink(datafile.readlink)
		puts file
	when datafile.file?
		datefile.make_symlink($time.relative_path_from(datefile.dirname))
		puts file
	else
		STDERR.puts "file '#{file}' does not exist"
	end
end


ARGV.each do |file|
	generate_date(Pathname.new(file))
end
