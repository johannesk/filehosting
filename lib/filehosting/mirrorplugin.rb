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

	class MirrorPlugin

		def initialize(config)
			@config= config
		end

		# This method should check for all new files in
		# location. Files are of the following form:
		# { uuid => [fileinfo, data] }
		# It should return [[fileinfo, filedata, data]] for
		# all new files.
		def check_new(location, files)
			raise NotImplementedError
		end

		# This method should check for all changed files in
		# location. Files are of the following form:
		# { uuid => [fileinfo, data] }
		# It should return [[fileinfo, filedata, data]] for
		# all changed files.
		def check_update(location, files)
			raise NotImplementedError
		end

	end

end
