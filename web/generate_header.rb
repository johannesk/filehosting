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
	STDERR.puts "usage: ./generate_header.rb <file> [file]..."
	exit 1
end

require "pathname"
require "filemagic"

$data= Pathname.new("data")
$date= Pathname.new("date")
$header= Pathname.new("header")


begin
	$fm= FileMagic.new(FileMagic::MAGIC_MIME)

	def generate_header(file)
		datafile= $data+file
		datefile= $date+file
		headerfile= $header+file
		case
		when datafile.directory?
			headerfile.mkdir unless headerfile.directory?
			datafile.children.each do |child|
				generate_header(child.relative_path_from($data))
			end
			puts file
		when headerfile.exist?
			return
		when datafile.symlink?
			headerfile.make_symlink(datafile.readlink)
			puts file
		when datafile.file?
			unless datefile.file?
				STDERR.puts "datefile for '#{file}' missing" unless datefile.file?
				return
			end
			File.open(headerfile, "w") do |f|
				f.puts "Content-Length: #{datafile.size}"
				f.puts "Content-Type: #{$fm.file(datafile.to_s).sub(/; .*?$/, "")
	}"
				f.puts "Last-Modified: #{datefile.read}"
				f.puts
			end
			puts file
		else
			STDERR.puts "file '#{file}' does not exist"
		end
	end


	ARGV.each do |file|
		generate_header(Pathname.new(file))
	end

ensure
	$fm.close
end
