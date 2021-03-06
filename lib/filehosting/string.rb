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

class String

	alias :to_text :to_s

	def dir_encode
		self.gsub("%", "%&").gsub("/", "%#").gsub(".", "%.")
	end

	def dir_decode
		self.gsub("%.", ".").gsub("%#", "/").gsub("%&", "%")
	end

	def uri_decode
		res= ""
		self.gsub("+", " ")=~ /^/
		rem= $'
		while $'=~ /%([A-Za-z0-9]{2})/
			rem= $'
			res+= $`
			res<< $1.to_i(16)
		end
		res+rem
	end

	def uri_encode
		self.gsub(/[^a-zA-Z0-9\-_ ]/) do |c|
			"%#{ c[0]<16 ? "0" : "" }#{ c[0].to_s(16).upcase }"
		end.gsub(" ", "+")
	end

	def user_decode
		self.gsub("\\\\", "\\").gsub("\\n", "\n").gsub("\\r", "\r").gsub("\\\"", "\"").gsub(/\\(.)/, "\\1")
	end

	def self.random(size= 32)
		res= ""
		size.times { res<< rand(256) }
		res
	end

	def username
		self
	end

end

