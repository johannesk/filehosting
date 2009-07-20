#!/usr/bin/ruby
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

require "filehosting/binenv"
require "filehosting/mirror"
require "filehosting/mirrorlocation"
require "filehosting/yamltools"
require "filehosting/internaldatacorruptionerror"

FileHosting::BinEnv.new do |env|
	httpmirrorstorage= env.config.storage.prefix("httpmirror")
	mirror= FileHosting::Mirror.new(env.config)
	mirrorstorage= env.config.storage.prefix("mirror")
	httpmirrorstorage.records.each do |filename|
		case filename
		when /^urllist\/(.*?)$/
			name= $1.dir_decode
			data= FileHosting::YAMLTools.parse_array(httpmirrorstorage.read(filename, String), Array)
			data.each do |a|
				raise FileHosting::InternalDataCorruptionError unless a.size == 4
				url= a[0]
				pattern= a[1]
				tags= a[2]
				source= a[3]
				raise FileHosting::InternalDataCorruptionError unless String === url
				raise FileHosting::InternalDataCorruptionError unless Regexp === pattern
				raise FileHosting::InternalDataCorruptionError unless Array === tags
				tags.each do |tag|
					raise FileHosting::InternalDataCorruptionError unless String === tag
				end
				raise FileHosting::InternalDataCorruptionError unless String === source or source == nil
				location= FileHosting::MirrorLocation.new
				location.type= :http
				location.location= url
				location.pattern= pattern
				location.tags= tags
				location.source= source
				mirror.register(name.dir_encode, location)
				if $human
					puts "--"
					puts location.to_text
				end
			end
		when /^filelist\/(.*?)$/
			name= $1.dir_decode
			data= FileHosting::YAMLTools.parse_array(httpmirrorstorage.read(filename, String), Array)
			data.collect! do |a|
				raise InternalDataCorruptionError unless a.size == 2
				url= a[0]
				uuid= a[1]
				raise FileHosting::InternalDataCorruptionError unless String === url
				raise FileHosting::InternalDataCorruptionError unless String === uuid
				if $human
					puts url
				end
				[uuid, url]
			end
			mirrorstorage.store_data("files/#{name.dir_encode}", {"http" => data}.to_yaml)
		end
	end
end
