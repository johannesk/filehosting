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
require "filehosting/array"

class Hash

	# Display a number in a human readable way if requested. If
	# use is given, use specifies which keys are used and in which
	# order.
	def to_text(use= nil)
		left= Hash.new
		(use or keys).each do |key|
			left[key]=if key.respond_to?(:to_text)
				key.to_text
			else
				key.to_s
			end
		end
		size= left.values.inject(0) { |n,m| n > m.size ? n : m.size }
		(use or keys).collect do |key|
			v= if self[key].respond_to?(:to_text)
				self[key].to_text
			else
				self[key].to_s
			end
			if v=~ /\n/
				v= "{\n" + v + "\n}"
				v.gsub!("\n", "\n\t")
			end
			left[key] + ": " + (" " * (size - left[key].size)) + v
		end.join("\n")
	end

	def dir_encode
		keys.sort.collect do |key|
			key.to_s.dir_encode.gsub("=", "%=").gsub("&", "&%") +
			"=" +
			self[key].to_s.dir_encode.gsub("=", "%=").gsub("&", "&%")
		end.join("&")
	end

end

