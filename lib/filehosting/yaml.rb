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

require "yaml"

class Object

	def to_yaml(opts = Hash.new)
		YAML::quick_emit(object_id, opts) do |out|
			out.map(taguri, to_yaml_style) do |map|
				to_yaml_properties.each do |m|
					map.add(m[1..((m.index(?.) or 0)-1)], eval(m))
				end
			end
		end
	end

end

