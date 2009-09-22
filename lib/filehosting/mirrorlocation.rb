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

require "filehosting/hash"
require "filehosting/yaml"
require "filehosting/regexp"
require "filehosting/internaldatacorruptionerror"

require "yaml"

module FileHosting

	# This class holds the information about a specific location
	# which should be mirrored.
	class MirrorLocation

		include YAMLPropertiesByEval

		# which type of mirror
		attr_accessor :type

		# the location of the mirror
		attr_accessor :location

		# the pattern which all new filenames must match
		attr_accessor :pattern

		# which tags should the mirrored files have
		attr_accessor :tags

		# with what should the source be overwritten
		attr_accessor :source

		def initialize(type= nil, location= nil, pattern= nil, tags= nil, source= nil)
			@type= type
			@location= location
			@pattern= pattern
			@tags= tags
			@source= source
		end

		def to_hash
			{
				:type     => @type,
				:location => @location,
				:pattern  => @pattern,
				:tags     => @tags,
				:source   => @source,
			}
		end

		def to_yaml_hash
			{
				"type"     => lambda { @type },
				"location" => lambda { @location },
				"pattern"  => lambda { @pattern.source },
				"tags"     => lambda { @tags },
				"source"   => lambda { @source },
			}
		end

		def to_text
			to_hash.to_text([:type, :location, :pattern, :tags, :source])
		end

		def to_yaml_type
			"!filehosting/mirrorlocation"
		end

	end

end

YAML.add_domain_type("filehosting.yaml.org,2002", "mirrorlocation") do |tag, value|
	begin
		res= FileHosting::MirrorLocation.new
		res.type= value["type"].to_sym
		res.location= value["location"].to_s
		res.pattern= /#{value["pattern"].to_s}/
		res.tags= value["tags"].collect { |x| x.to_s }
		res.source= value["source"].to_s
		res
	rescue
		raise FileHosting::InternalDataCorruptionError
	end
end

