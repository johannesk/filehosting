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
require "base64"

module FileHosting

	class Mirror

		# This class holds the information about a password. For a
		# specific location.
		class Auth

			include YAMLPropertiesByEval

			def self.http_basic_auth(username, password, locations)
				Auth.new(:http_basic_auth, locations, username, password)
			end

			# which type of authentication
			attr_accessor :auth_type

			# the locations this authentication is for
			attr_accessor :locations

			# identifier
			attr_accessor :identifier

			# the auth data
			attr_accessor :auth_data

			def initialize(auth_type= nil, locations= nil, identifier= nil, auth_data= nil)
				@auth_type= auth_type
				if locations
					locations= [locations].flatten
				end
				@locations= locations
				@identifier= identifier
				@auth_data= auth_data
			end

			# Returns whether this auth data is usable in
			# the given location. Returns not a boolean,
			# but the length of the used location prefix.
			def usable_in?(location)
				locations.collect { |l| location[0..(l.size-1)] == l ? l.size : nil }.sort[-1]
			end

			def to_hash
				{
					:type       => @auth_type,
					:locations  => @locations,
					:identifier => @identifier,
					:data       => @data,
				}
			end

			def to_yaml_hash
				{
					"type"       => lambda { @auth_type.to_s },
					"locations"  => lambda { @locations },
					"identifier" => lambda { @identifier },
					"auth_data"  => lambda { Base64.encode64(@auth_data.to_yaml).gsub(/\n/, "") },
				}
			end

			def to_text
				to_hash.to_text([:type, :locations, :identifier])
			end

			def to_yaml_type
				"!filehosting/mirror/auth"
			end

		end

	end

end

YAML.add_domain_type("filehosting.yaml.org,2002", "mirror/auth") do |tag, value|
	begin
		res= FileHosting::Mirror::Auth.new
		res.auth_type= value["type"].to_sym
		res.locations= value["locations"]
		raise FileHosting::InternalDataCorruptionError unless Array === res.locations
		raise FileHosting::InternalDataCorruptionError unless res.locations.all? { |x| String === x }
		res.identifier= value["identifier"].to_s
		res.auth_data= YAML.load(Base64.decode64(value["auth_data"].to_s))
		res
	rescue
		raise FileHosting::InternalDataCorruptionError
	end
end

