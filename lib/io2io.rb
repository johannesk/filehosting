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

require "io2io_c"

module IO2IO

	def self.do(input, output, size= nil, interval= nil)
		if block_given? and interval
			done= 0
			while !size or (done + interval) <= size
				tmp= do_c(input, output, interval)
				done+= tmp
				yield done
				return done if tmp < interval
			end
			if done!= size
				do_c(input, output, size-(done-interval))
				yield size
			end
		else
			do_c(input, output, size)
		end
	end

end
