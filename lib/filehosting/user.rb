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
require "filehosting/internaldatacorruptionerror"

require "yaml"
require "digest/sha2"

module FileHosting

	# This class holds all the informations about a user.
	class User

		include YAMLPropertiesByEval

		# the users name
		attr_accessor :username

		# the users groups
		attr_accessor :groups

		# whether this user is active
		attr_accessor :active

		# the salt used for the password hashing
		attr_accessor :salt

		# the type of the password hash
		attr_accessor :hash_type

		# the password hash
		attr_accessor :hash

		def initialize(username, password)
			@active= true
			@username= username if username
			if password
				@salt= String.random
				@hash_type= "SHA-256"
				generate_hash
			end
		end

		def generate_hash(password)
			@hash= hash(password)
		end

		def check_password(password)
			@active and
			@hash == hash(password)
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
				:username   => @username,
				:groups     => @groups,
				:active     => @active,
				:salt       => @salt,
				:hash_type  => @hash_type,
				:hash       => @hash
			}
		end

		def to_text
			to_hash.to_text([:username, :groups, :salt, :hash_type, :hash])
		end

		def to_yaml_properties
			{
				"username"    => lambda { @username },
				"groups"      => lambda { @groups },
				"active"      => lambda { @active },
				"salt"        => lambda { @salt },
				"hash_type"   => lambda { @hash_type },
				"hash"        => lambda { @hash },
			}
		end

		def to_yaml_type
			"!filehosting/user"
		end

		private

		def hash(password)
			cleartext= password+@salt
			case @hash_type
			when "SHA-256"
				Digest::SHA256.hexdigest(cleartext)
			else
				raise NotImplementedError
			end
		end

	end

end

YAML.add_domain_type("filehosting.yaml.org,2002", "user") do |tag, value|
	begin
		res= FileHosting::User.new
		res.username= value["username"].to_s
		res.groups= value["groups"].collect { |s| s.to_s }
		res.active= value["active"]
		res.salt= valuel["salt"].to_s
		res.hash_type= valuel["hash_type"].to_s
		res.hash= valuel["hash"].to_s
		res
	rescue
		raise FileHosting::InternalDataCorruptionError
	end
end

