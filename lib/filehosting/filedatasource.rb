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

require "filehosting/datasource"
require "filehosting/fileinfo"

require "pathname"
require "yaml"

module FileHosting

	# FileDataSource stores all data in the filesystem
	class FileDataSource < DataSource

		def initialize(storage)
			@filesdir= Pathname.new(storage)+"files"
			@metadatadir= Pathname.new(storage)+"metadata"
			@tagsdir= Pathname.new(storage)+"tags"
			[@filesdir, @metadatadir, @tagsdir].each do |dir|
				dir.mkdir unless dir.directory?
			end
		end

		def search_tags(tags)
			count= Hash.new(0)
			tags.each do |tag|
				uuids_by_tag(tag).each do |uuid|
					count[uuid]+= 1
				end
			end
			count.keys.sort { |a,b| count[a] <=> count[b] }.collect { |uuid| fileinfo(uuid) }
		end

		def fileinfo(uuid)
			file= @metadatadir+uuid.to_s
			return nil unless file.file?
			res= YAML.load(file.read)
			return nil unless FileInfo === res
			res
		end

		# get all files uuid with this tag
		def uuids_by_tag(tag)
			file= @tagsdir+tag.to_s
			return [] unless file.file?
			res= YAML.load(file.read)
			return [] unless Array === res
			res
		end

	end

end

