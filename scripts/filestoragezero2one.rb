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

require "filehosting/binenv"
require "filehosting/filestorageversionmismatcherror"

require "pathname"

FileHosting::BinEnv.new(FileHosting::FileStorageVersionMismatchError) do |env|
	unless FileHosting::FileStorageVersionMismatchError === env.error
		STDERR.puts "no filestorage with wrong version found"
		exit 3
	end

	# we only work on version 0
	if env.error.actual != 0
		env.error.expected= 0
		raise env.error
	end

	# write the new version
	versionfile= env.error.path+".version"
	versionfile.open("w") { |f| f.write(1) }
end
