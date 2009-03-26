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

# Please don't read this file. This sourcecode is a realy bad shape.

require "filehosting/web-tiny"
require "filehosting/html"
require "filehosting/error"
require "filehosting/nosuchfileerror"

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
			# caching for files.
			if path =~ /^files\//
				res= get_file($')
				return res if res
			end
			@config.cache.retrieve("web/"+path.dir_encode+"?"+args.dir_encode) do
				create_page(path, args)
			end
		end

		def get_file(uuid)
			begin
				uuid= UUID.parse(uuid)
			rescue ArgumentError
				return nil
			end
			begin
				info= @config.datasource.fileinfo(uuid)
				io= @config.datasource.filedata_io(uuid)
				return [
					"Content-Type: #{info.mimetype}\n" +
					"Content-Length: #{info.size}\n" +
					"Content-Disposition: attachment;filename=#{info.filename}\n" +
					"\n",
					io
				]
			rescue NoSuchFileError
				return nil
			end
		end

		# Creates a page and stores it into the cache.
		def create_page(path, args, input= nil, type= nil)
			direction= path.split("/")
			unless input
				data, tags= page(direction,args)
			else
				data= page_input(direction, args, input, type)
			end
			return unless data
			size= if data=~ /\n\n/
				$'
			else
				data
			end.size
			data= "Content-Length: #{size}\n" + data
			[data , tags || []]
		end

		def page(direction, args)
			case direction.shift
			when nil
				page_search(direction, args)
			when "fileinfo"
				page_fileinfo(direction, args)
			when "search"
				page_search(direction, args)
			when "classic"
				page_classic(direction, args)
			when "update"
				page_update(direction, args)
			when "remove"
				page_remove(direction, args)
			when "files" # regular files are handled in get_page, this is only for errors
				page_fileinfo(direction, args)
			else
				[HTML.error_page("wrong arguments", 404), []]
			end
		end

		def page_input(direction, args, input, type)
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

		def page_fileinfo(path, args)
			page_with_fileinfo(path) do |fileinfo|
				[HTML.page(fileinfo.uuid.to_s, fileinfo.to_html , "fileinfo.css"), ["files/#{fileinfo.uuid.to_s}"]]
			end
		end

		def page_update(path, args)
			page_with_fileinfo(path) do |fileinfo|
				updated= false
				[HTML.page("update: #{fileinfo.uuid}", HTML.use_template("update.eruby", binding), "update.css"), ["files/#{fileinfo.uuid.to_s}"]]
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

		def page_remove(path, args)
			page_with_fileinfo(path) do |fileinfo|
				[HTML.page("remove :#{fileinfo.uuid.to_s}", HTML.use_template("remove.eruby", binding) , "remove.css"), ["files/#{fileinfo.uuid.to_s}"]]
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

		def page_search(path, args)
			case args["tags"]
			when nil
				tags= @config.datasource.tags.sort
				[HTML.page("search", HTML.use_template("search_new.eruby", binding), "search.css"), ["tags"]]
			when String
				tags= args["tags"].split("+")
				search_result= @config.datasource.search_tags(tags)
				[
					HTML.page("search: #{tags}", HTML.use_template("search.eruby", binding), "search.css"),
					tags.collect { |tag| "tags/#{tag}" } + search_result.collect { |file| "files/#{file.uuid.to_s}" }
				]
			else
				HTML.error_page("wrong arguments", 404)
			end
		end

		def page_classic(path, args)
			tags= path
			search_result= @config.datasource.search_tags(tags)
			[
				HTML.page(tags.join("/"), HTML.use_template("classic.eruby", binding), ["classic.css", "sortable.js"]),
				tags.collect { |tag| "tags/#{tag}" } + search_result.collect { |file| "files/#{file.uuid.to_s}" }
			]
		end

	end

end
