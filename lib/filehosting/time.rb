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

class Time

	def form
		strftime("%d.%I.%Y %H:%M:%S")
	end

	def self.from_form(str)
		raise ArgumentError.new("not a valid time") unless str=~ /^[^0-9]*([0-2]?[0-9]|3[01])[^0-9]+(0[1-9]|1[0-2])[^0-9]+([0-9]{1,4})[^0-9]+([01]?[0-9]|2[0-3])[^0-9]+([0-5]?[0-9])[^0-9]+([0-5]?[0-9])[^0-9]*$/
		Time.local($3, $2, $1, $4, $5, $6)
	end

end

