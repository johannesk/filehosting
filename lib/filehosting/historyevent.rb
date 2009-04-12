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

module FileHosting

	# This class holds all the informations about a file.
	class HistoryEvent

		include YAMLPropertiesByEval

		# when did the history action happen
		attr_accessor :time

		# which user triggered this entry
		attr_accessor :user

		# which action was performed
		attr_accessor :action

		# the object of the action
		attr_accessor :entity

		# the data which changed due to the history event
		attr_accessor :data

		def initialize(user= nil, action= nil, entity= nil, data= nil)
			@user= user
			@action= action
			@entity= entity
			@data= data
			@time= Time.now
		end

		def to_hash
			{
				:time   => @time,
				:user   => @user,
				:entity   => @entity,
				:action => @action,
				:data   => @data
			}
		end

		def to_text
			to_hash.to_text([:time, :user, :uuid, :action, :data])
		end

		def to_yaml_properties
			{
				"time"   => lambda { @time },
				"user"   => lambda { @user },
				"entity" => lambda { @entity.to_s },
				"action" => lambda { @action.to_s },
				"data"   => lambda do
					res= Hash.new
					@data.each do |key, value|
						res[key.to_s]= value
					end
					res
				end
			}
		end

		def to_yaml_type
			"!filehosting/historyevent"
		end

	end

end

YAML.add_domain_type("filehosting.yaml.org,2002", "historyevent") do |tag, value|
	begin
		res= FileHosting::HistoryEvent.new
		res.time= value["time"]
		raise FileHosting::InternalDataCorruptionError unless Time === res.time
		res.user= value["user"].to_s
		res.entity= value["entity"].to_s
		res.action= value["action"].to_sym
		res.data= Hash.new
		value["data"].to_hash.each do |key, value|
			res.data[key.to_sym]= value
		end
		res
	rescue
		raise FileHosting::InternalDataCorruptionError
	end
end

