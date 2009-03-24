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

require "filehosting/web"

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
		def get_page(path, args)
			file= StaticDir+path
			return nil unless file.cleanpath == file
			if file.file?
				return File.new(file)
			end
			file= CacheDir+(path.dir_encode+"?"+args.dir_encode)
			if file.file?
				File.new(file)
			else
				# This is done here and not it
				# create_page, because we don't want
				# caching for files.
				if path =~ /^files\//
					res= get_file($')
					return res if res
				end
				create_page(path, args)
				if file.file?
					File.new(file)
				else
					nil
				end
			end
		end

		def get_file(uuid)
			begin
				uuid= UUID.parse(uuid)
			rescue ArgumentError
				return nil
			end
			begin
				info= @datasource.fileinfo(uuid)
				io= @datasource.filedata_io(uuid)
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

		# Creates a page and puts it into the cache.
		def create_page(path, args)
			file= CacheDir+(path.dir_encode+"?"+args.dir_encode)
			direction= path.split("/")
			data= case direction.shift
			when "fileinfo"
				"Content-Type: text/html; charset=utf-8\n\n" +
				page_fileinfo(direction, args)
			when "search"
				"Content-Type: text/html; charset=utf-8\n\n" +
				page_search(direction, args)
			when "files" # regular files are handled in get_page, this is only for errors
				"Content-Type: text/html; charset=utf-8\n\n" +
				page_fileinfo(direction, args)
			else
				"Content-Type: text/html; charset=utf-8\n\n" +
				FileHosting::HTML.error_page("wrong arguments")
			end
			return unless data
			data=~ /\n\n/
			data= "Content-Length: #{$'.size}\n" + data
			file.dirname.mkpath unless file.dirname.directory?
			File.open(file, "w") do |f|
				f.write(data)
			end
		end

		def page_fileinfo(path, args)
			if path.size != 1
				return FileHosting::HTML.error_page("wrong arguments")
			end
			begin
				uuid= UUID.parse(path[0])
			rescue ArgumentError => e
				return FileHosting::HTML.error_page(e)
			end
			begin
				fileinfo= @datasource.fileinfo(uuid)
				FileHosting::HTML.page(fileinfo.filename.to_html, fileinfo.to_html, "fileinfo.css")
			rescue FileHosting::Error => e
				FileHosting::HTML.error_page(e)
			end
		end

		def page_search(path, args)
			case args["tags"]
			when nil
				FileHosting::HTML.page("search", FileHosting::HTML.use_template("search_new.eruby", binding), "search.css")
			when String
				tags= args["tags"].split("+")
				search_result= @datasource.search_tags(tags)
				FileHosting::HTML.page("search: #{tags.to_html}", FileHosting::HTML.use_template("search.eruby", binding), "search.css")
			else
				FileHosting::HTML.error_page("wrong arguments")
			end
		end

	end

end
