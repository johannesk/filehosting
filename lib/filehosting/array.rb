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

require "filehosting/string"
require "filehosting/integer"
require "filehosting/hash"

class Array

	# Display an array in a human readable way
	def to_text
		items= collect do |value|
			if value.respond_to?(:to_text)
				value.to_text
			else
				value.to_s
			end
		end
		unless items.find { |x| x=~ /\n/ }
			items.join(", ")
		else
			items.join("\n\n")
		end
	end

	alias :flatten_filehosting :flatten
	def flatten(d= nil)
		return flatten_filehosting unless d
		return self if d == 0
		res= []
		self.each do |x|
			case x
			when Array
				res+= x.flatten(d-1)
			else
				res<< x
			end
		end
		res
	end

end

