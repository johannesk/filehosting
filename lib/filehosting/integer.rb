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

class Integer

	# display a number in a human readable way if requested
	def to_text
		return self.to_s unless $human and self > 999
		res= self.to_f
		exp= 0
		while res > 999
			exp+= 1
			res/= 1024
		end
		return "#{(res*10).round.to_f/10}#{["", "K", "M", "G", "T", "P"][exp]}"
	end

end

