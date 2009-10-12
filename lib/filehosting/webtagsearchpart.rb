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

require "filehosting/webpart"
require "filehosting/html"
require "filehosting/fileinfo"
require "filehosting/string"

require "filehosting/uuid"

module FileHosting

	# Displays an input to search for tags.
	class WebTagSearchPart < WebPart

		# The block is used to build url's. The block is
		# called everytime a url is build it's arguments
		# are an array of tags. The block should return an
		# url.
		def initialize(config, tags, &block)
			@url_builder= block
			super(config, "tagsearch/#{tags.collect { |t| t.dir_encode }.join("/")}") do
				# mark all non existing tags
				tag_exists= Hash.new(true)
				tags.each do |tag|
					tag_exists[tag]= false unless config.datasource.tag_exists?(tag)
				end

				guessed_tags= Hash.new([])
				tags.each_with_index do |tag, i|
					# get the guessed tags
					guessed_tags[tag]= config.datasource.guess_tag(tag)
					if !tag_exists[tag] and guessed_tags[tag][0] and tag.downcase == guessed_tags[tag][0].downcase
					# automaticly correct
					# in case of wrong
					# case
						new= guessed_tags[tag].delete_at(0)
						tags[i]= new
						guessed_tags[new]= guessed_tags[tag]
						guessed_tags.delete(tag)
						tag_exists.delete(tag)
					end
				end

				HTML.use_template("tagsearchpart.eruby", binding)
			end
		end

		def build_url(tags)
			@url_builder.call(tags)
		end

	end

end

