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

require "filehosting/integer"
require "filehosting/yaml"
require "filehosting/internaldatacorruptionerror"

require "yaml"
require "uuidtools"

module FileHosting

	# This class holds all the informations about a file.
	class FileInfo

		# the RFC 4122 uuid for this file. It should always be
		# stored as a UUID object.
		attr_accessor :uuid

		# the file name
		attr_accessor :filename

		# where the file comes from
		attr_accessor :source

		# the mimetype of the file
		attr_accessor :mimetype

		# the size of the file
		attr_accessor :size

		# the type of the hash (eg. "SHA-256")
		attr_accessor :hash_type

		# the hash data as string
		attr_accessor :hash

		# the tags of the file
		attr_accessor :tags

		# the history of this file
		#attr_accessor :history

		def to_text
			"name:      #{@filename}\n"+
			"uuid:      #{@uuid}\n"+
			"tags:      #{@tags.join(", ")}\n"+
			"mimetype:  #{@mimetype}\n"+
			"size:      #{@size.to_text}\n"+
			"hash type: #{@hash_type}\n"+
			"hash:      #{@hash}\n"+
			"source:    #{@source}"
		end

		# all subclasses of FileInfo should only serialize FileInfo Attributes
		def to_yaml_properties
			["@uuid.to_s", "@filename", "@source", "@mimetype", "@size", "@hash_type", "@hash", "@tags"]#, "@history"]
		end

		def to_yaml_type
			"!filehosting/fileinfo"
		end

	end

end

YAML.add_domain_type("filehosting.yaml.org,2002", "fileinfo") do |tag, value|
	begin
		res= FileHosting::FileInfo.new
		res.uuid= UUID.parse(value["uuid"])
		res.filename= value["filename"].to_s
		res.source= value["source"].to_s
		res.mimetype= value["mimetype"].to_s
		res.size= value["size"].to_i
		res.hash_type= value["hash_type"].to_s
		res.hash= value["hash"].to_s
		res.tags= value["tags"].collect { |x| x.to_s }
		#res.history= value["history"]
		res
	rescue
		raise InternalDataCorruptionError
	end
end

