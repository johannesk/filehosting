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
require "filehosting/hash"

require "yaml"
autoload :UUID, "filehosting/uuid"

module FileHosting

	autoload :InternalDataCorruptionError, "filehosting/internaldatacorruptionerror"

	# This class holds all the informations about a file.
	class FileInfo

		include YAMLPropertiesByEval

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
		attr_accessor :hash_data

		# the tags of the file
		attr_accessor :tags

		# the date of the filedata
		attr_accessor :data_time

		# the date of the metadata
		attr_accessor :info_time

		# the date which can be configured by the user
		attr_accessor :user_time

		# the groups of this file
		attr_accessor :groups

		def initialize
			@uuid= UUID.random_create
		end

		def -(other)
			res= Hash.new
			a= self.to_hash
			b= other.to_hash
			a.each_key do |key|
				res[key]= a[key] unless a[key] == b[key]
			end
			res
		end

		def ==(other)
			to_hash == other.to_hash
		end

		def to_hash
			{
				:filename  => @filename,
				:uuid      => @uuid,
				:tags      => @tags,
				:mimetype  => @mimetype,
				:size      => @size,
				:hash_type => @hash_type,
				:hash      => @hash_data,
				:source    => @source,
				:data_time => @data_time,
				:info_time => @info_time,
				:user_time => @user_time,
				:groups    => @groups,
			}
		end

		def to_text
			to_hash.to_text([:filename, :uuid, :tags, :user_time, :mimetype, :size, :hash_type, :hash, :source, :info_time, :data_time])
		end

		# all subclasses of FileInfo should only serialize FileInfo Attributes
		def to_yaml_hash
			{
				"uuid"      => lambda { @uuid.to_s },
				"filename"  => lambda { @filename },
				"source"    => lambda { @source },
				"mimetype"  => lambda { @mimetype },
				"size"      => lambda { @size },
				"hash_type" => lambda { @hash_type },
				"hash"      => lambda { @hash_data },
				"tags"      => lambda { @tags },
				"data_time" => lambda { @data_time },
				"info_time" => lambda { @info_time },
				"user_time" => lambda { @user_time },
				"groups"    => lambda { @groups },
			}
		end
		alias :rule_operand :to_yaml_hash

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
		res.hash_data= value["hash"].to_s
		res.tags= if value["tags"].nil?
			nil
		else
			value["tags"].collect { |x| x.to_s }
		end
		raise FileHosting::InternalDataCorruptionError unless value["data_time"].nil? or Time === value["data_time"]
		res.data_time= value["data_time"]
		raise FileHosting::InternalDataCorruptionError unless value["info_time"].nil? or Time === value["info_time"]
		res.info_time= value["info_time"]
		raise FileHosting::InternalDataCorruptionError unless value["user_time"].nil? or Time === value["user_time"]
		res.user_time= value["user_time"]
		res.groups= if value["groups"].nil?
			nil
		else
			value["groups"].collect { |x| x.to_s }
		end
		res
	rescue
		raise FileHosting::InternalDataCorruptionError
	end
end

