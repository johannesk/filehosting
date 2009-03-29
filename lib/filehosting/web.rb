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
require "filehosting/webredirect"

require "pathname"
require "uuidtools"

module FileHosting

	autoload :WebFileInfoPage, "filehosting/webfileinfopage"
	autoload :WebUpdatePage,  "filehosting/webupdatepage"
	autoload :WebRemovePage, "filehosting/webremovepage"
	autoload :WebAddPage, "filehosting/webaddpage"
	autoload :WebSearchPage, "filehosting/websearchpage"
	autoload :WebClassicPage, "filehosting/webclassicpage"
	autoload :WebSourceCode, "filehosting/websourcecode"
	autoload :WebFile, "filehosting/webfile"
	autoload :Web404Page, "filehosting/web404page"

	class Web

		# Returns a String, an IO, or an Array of String's and
		# IO's. The String holds the data, from an IO can the
		# data be read. And in case of an Array all String's
		# and IO's have to be parsed to get the full data.
		def get_page(path, args, input= nil, type= nil)
			if input
				return create_page(path, args, input, type)
			end
			file= StaticDir+path
			return nil unless file.cleanpath == file
			if file.file?
				return File.new(file)
			end
			create_page(path, args, input, type)
		end

		# Creates a page and stores it into the cache.
		def create_page(path, args, input= nil, type= nil)
			cache_name= "web/"+path.dir_encode+"?"+args.dir_encode
			res= @config.cache.retrieve_io(cache_name)
			return res if res
			direction= path.split("/")
			page= unless input
				page_switch(direction,args)
			else
				page_input_switch(direction, args, input, type)
			end
			case
			when page.status == 404
				@config.cache.store_link(cache_name, "weberror/404", page.tags)
				create_404_page
			when WebRedirect === page
				location= page.location.sub(/^\//, "")
				location=~ /\?/
				path= $` || location
				args= self.class.parse_get($' || "")
				@config.cache.store_link(cache_name, "web/"+path.dir_encode+"?"+args.dir_encode, page.tags)
				create_page(path, args)
			when (not page.cachable)
				page.to_output
			else
				@config.cache.store(cache_name, page.to_output, page.tags)
				create_page(path, args)
			end
		end

		def create_404_page
			cache_name= "weberror/404"
			res= @config.cache.retrieve_io(cache_name)
			return res if res
			page= Web404Page.new(config)
			@config.cache.store(cache_name, page.to_output, page.tags)
			create_404_page
		end

		def page_switch(direction, args)
			case
			when direction == []
				WebRedirect.new(config, "/search")
			when direction == ["add"]
				WebAddPage.new(config)
			when direction == ["sourcecode"]
				WebSourceCode.new(config)
			when (direction == ["search"] and (args.keys - ["tags"]) == [])
				tags= (args["tags"] || "").split("+")
				WebSearchPage.new(config, *tags)
			when (direction.size == 2 and direction[0] == "files")
				WebFile.new(config, direction[1])
			when (direction.size == 2 and direction[0] == "fileinfo")
				WebFileInfoPage.new(config, direction[1])
			when (direction.size == 2 and direction[0] == "update")
				WebUpdatePage.new(config, direction[1])
			when (direction.size == 2 and direction[0] == "remove")
				WebRemovePage.new(config, direction[1])
			when direction[0] == "classic"
				WebClassicPage.new(config, *direction[1..-1])
			else
				Web404Page.new(config)
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
