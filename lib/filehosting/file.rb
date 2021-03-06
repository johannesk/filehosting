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

require "fileutils"

class File

		# Creates a temporary file and opens it for writing.
		# Behaves like open with a block if a block is given.
		def self.mktemp
			@tmpfile= true
			path= `mktemp`.strip
			if block_given?
				filename= nil
				begin
					File.open(path, "w") do |f|
						filename= f.path
						yield f
					end
				ensure
					FileUtils.rm(filename)
				end
			else
				File.open(path, "w")
			end
		end

		# Test whether this file was created with mktemp.
		def tmpfile?
			@tmpfile
		end

end

