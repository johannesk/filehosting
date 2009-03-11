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

module FileHosting

	# This class holds all the informations about a file.
	class FileInfo

		# the uniq identification for this file
		attr_accessor :uid

		# the file name
		attr_accessor :name

		# where the file comes from
		attr_accessor :source

		# where to get the file now
		attr_accessor :url

		# the mimetype of the file
		attr_accessor :mimetype

		# the size of the file
		attr_accessor :size

		# the tags of the file
		attr_accessor :file

		# the history of this file
		attr_accessor :history

	end

end

