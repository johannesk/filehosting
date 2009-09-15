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

if ARGV.size != 0
	STDERR.puts "usage: ./remove_unused_date.rb"
	exit 1
end

require "pathname"

$files= []
Pathname.new(".").children.each do |file|
	next unless file.file?
	if file.basename == file.read
		$files<< file.basename
	end
end

def find_files(file)
	case
	when file.directory?
		file.children.each do |child|
			find_files(child)
		end
	when file.symlink?
		$files.delete(file.readlink.basename)
	else
		STDERR.puts "file '#{file}' does not exist"
	end
end


find_files(Pathname.new("date"))
$files.each do |file|
	puts file
	file.delete
