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

# Please don't read this file. This sourcecode is in a realy bad shape.

require "filehosting/web-tiny"
require "filehosting/html"
require "filehosting/error"
require "filehosting/nosuchfileerror"
require "filehosting/yamltools"
require "filehosting/webfileinfopage"
require "filehosting/webupdatepage"
require "filehosting/webremovepage"
require "filehosting/webaddpage"
require "filehosting/websearchpage"
require "filehosting/webclassicpage"
require "filehosting/websourcecode"
require "filehosting/webfile"

require "pathname"
require "uuidtools"

module FileHosting

	class Web

		# Returns a String, an IO, or an Array of String's and
		# IO's. The String holds the data, from an IO can the
		# data be read. And in case of an Array all String's
		# and IO's have to be parsed to get the full data.
		def get_page(path, args, input= nil, type= nil)
			if input
				return create_page(path, args, input, type)[0]
			end
			file= StaticDir+path
			return nil unless file.cleanpath == file
			if file.file?
				return File.new(file)
			end
			# This is done here and not it
			# create_page, because we don't want
			# caching for files and sourcecode.
			return WebSourceCode.new(config).to_output if path=="sourcecode"
			if path =~ /^files\//
				return WebFile.new(config, $').to_output
			end
			@config.cache.retrieve("web/"+path.dir_encode+"?"+args.dir_encode) do
				create_page(path, args)
			end
		end

		# Creates a page and stores it into the cache.
		def create_page(path, args, input= nil, type= nil)
			direction= path.split("/")
			page= unless input
				page_switch(direction,args)
			else
				page_input_switch(direction, args, input, type)
			end
			[page.to_output, page.tags]
		end

		def page_switch(direction, args)
			case direction.shift
			when nil
				WebSearchPage.new(config)
			when "fileinfo"
				WebFileInfoPage.new(config, direction.shift)
			when "search"
				tags= (args["tags"] || "").split("+")
				WebSearchPage.new(config, *tags)
			when "classic"
				WebClassicPage.new(config, *direction)
			when "update"
				WebUpdatePage.new(config, direction.shift)
			when "remove"
				WebRemovePage.new(config, direction.shift)
			when "add"
				WebAddPage.new(config)
			else
				[HTML.error_page("wrong arguments", 404), []]
			end
		end

		def page_input_switch(direction, args, input, type)
			args= case type
			when "application/x-www-form-urlencoded"
				self.class.parse_get(input.read)
			else
				Hash.new
			end
			case direction.shift
			when "update"
				page_input_update(direction, args)
			when "remove"
				page_input_remove(direction, args)
			else
				HTML.error_page("wrong arguments", 404)
			end
		end

		def page_input_update(path, args)
			page_with_fileinfo(path) do |fileinfo|
				fileinfo.filename= args["filename"] if args["filename"]
				fileinfo.source= args["source"] if args["source"]
				fileinfo.tags= args["tags"].split("+") if args["tags"]
				begin
					@config.datasource.update_fileinfo(fileinfo)
				rescue Error => e
					return HTML.error_page(e)
				end
				updated= true
				HTML.page("update: #{fileinfo.uuid}", HTML.use_template("update.eruby", binding), "update.css")
			
			end
		end

		def page_input_remove(path, args)
			unless args["sure"] == "true"
				return HTML.error_page("wrong arguments", 404)
			end
			page_with_fileinfo(path) do |fileinfo|
				begin
					@config.datasource.remove_file(fileinfo.uuid)
				rescue Error => e
					return HTML.error_page(e)
				end
				HTML.page("remove :#{fileinfo.uuid.to_s}", HTML.use_template("removed.eruby", binding) , "remove.css")
			end
		end

		def page_with_fileinfo(path, &block)
			if path.size != 1
				return HTML.error_page("wrong arguments", 404)
			end
			begin
				uuid= UUID.parse(path[0])
			rescue ArgumentError => e
				return HTML.error_page(e, 404)
			end
			begin
				fileinfo= @config.datasource.fileinfo(uuid)
			rescue Error => e
				return HTML.error_page(e)
			end
			yield fileinfo
		end

	end

end
