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

require "filehosting/datasource"
require "filehosting/samplefileinfo"

module FileHosting

	# Sample DataSource generates Sample FileInfo's
	class SampleDataSource < DataSource

		def search_tags(tags, rule= nil)
			(1..rand(6)).collect { |x| SampleFileInfo.new }
		end

		def fileinfo(uuid)
			res= SampleFileInfo.new
			res.uuid= uuid
			res
		end

	end

end

