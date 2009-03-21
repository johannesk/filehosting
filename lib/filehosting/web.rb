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

require "filehosting/html"
require "filehosting/error"

require "pathname"
require "uuidtools"

module FileHosting

	class Web

		CacheDir= Pathname.new("/tmp/filehosting-cache")

		def initialize(datasource)
			@datasource= datasource
			CacheDir.mkdir unless CacheDir.directory?
		end

		# Returns an IO object where the requested page can be
		# read. Returns nil if the page can not be viewed.
		def get_page(page)
			file= CacheDir+page.dir_encode
			puts file
			if file.file?
				File.new(file)
			else
				create_page(page)
				if file.file?
					File.new(file)
				else
					nil
				end
			end
		end

		# Creates a page and puts it into the cache.
		def create_page(page)
			file= CacheDir+page.dir_encode
			args= page.split("/")
			puts args.size
			puts args
			data= case args.shift
			when "fileinfo"
				"Content-Type: text/html; charset=utf-8\n\n" +
				page_fileinfo(args)
			when "search"
				"Content-Type: text/html; charset=utf-8\n\n" +
				page_search(args)
			end
			return unless data
			data=~ /\n\n/
			data= "Content-Length: #{$'.size}\n" + data
			file.dirname.mkpath unless file.dirname.directory?
			File.open(file, "w") do |f|
				f.write(data)
			end
		end

		def page_fileinfo(args)
			if args.size != 1
				return nil
			end
			begin
				uuid= UUID.parse(args[0])
			rescue ArgumentError
				return nil
			end
			begin
				fileinfo= @datasource.fileinfo(uuid)
				return FileHosting::HTML.page(fileinfo.filename.to_html, fileinfo.to_html, "fileinfo.css")
			rescue FileHosting::Error => e
				return FileHosting::HTML.error_page(e)
			end
		end

		def page_search(args)
			case args.size
			when 0
				return FileHosting::HTML.page("search", FileHosting::HTML.use_template("search_new.eruby", binding), "search.css")
			when 1
				tags= args[0].split("+")
				search_result= @datasource.search_tags(tags)
				return FileHosting::HTML.page("search: #{tags.to_html}", FileHosting::HTML.use_template("search.eruby", binding), "search.css")
			else
				nil
			end
		end

	end

end
