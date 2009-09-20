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

require "filehosting/web-tiny"
require "filehosting/web_c"
require "filehosting/html"
require "filehosting/error"
require "filehosting/securityerror"
require "filehosting/yamltools"
require "filehosting/webredirect"
require "filehosting/file"

require "fileutils"
require "time"

module FileHosting

	autoload :WebFileInfoPage, "filehosting/webfileinfopage"
	autoload :WebUpdatePage,  "filehosting/webupdatepage"
	autoload :WebRemovePage, "filehosting/webremovepage"
	autoload :WebRemovedPage, "filehosting/webremovedpage"
	autoload :WebAddPage, "filehosting/webaddpage"
	autoload :WebSearchPage, "filehosting/websearchpage"
	autoload :WebClassicPage, "filehosting/webclassicpage"
	autoload :WebSourceCode, "filehosting/websourcecode"
	autoload :WebTagsPage, "filehosting/webtagspage"
	autoload :WebFile, "filehosting/webfile"
	autoload :WebLogin, "filehosting/weblogin"
	autoload :WebFeed, "filehosting/webfeed"
	autoload :WebCreateFeedPage, "filehosting/webcreatefeedpage"
	autoload :WebDownLoadList, "filehosting/webdownloadlist"
	autoload :Web404Page, "filehosting/web404page"
	autoload :Web401Page, "filehosting/web401page"
	autoload :WebYaml, "filehosting/webyaml"

	class Web

		# Returns a String, an IO, or an Array of String's and
		# IO's. The String holds the data, from an IO can the
		# data be read. And in case of an Array all String's
		# and IO's have to be parsed to get the full data.
		def get_page(path, args, input= nil, type= nil, date= nil)
			file= StaticDataDir+path
			return nil unless file.cleanpath == file
			if file.file?
				datefile= StaticDateDir+path
				return "Status: 304\n\n" if date and date.httpdate == datefile.read
				headerfile= StaticHeaderDir+path
				return [File.new(headerfile), File.new(file)]
			end
			create_page(path, args, input, type, date)
		end

		# Creates a page and stores it into the cache.
		def create_page(path, args, input= nil, type= nil, date= nil)
			cache_name= "web#{input ? "post" : ""}/#{@config.datasource.user.username}/#{path.dir_encode}?#{args.dir_encode}"
			return "Status: 304\n\n" if date and @config.cache.date(cache_name) == date
			res= @config.cache.retrieve(cache_name, IO)
			return res if res
			direction= path.split("/")
			page= nil
			tags= @config.datasource.count do
				begin
					page= case
					when direction[0] == "raw"
						WebYaml.new(config, direction[1..-1], input || StringIO.new(""))
					when input
						page_input_switch(direction, input, type, date)
					else
						page_switch(direction, args, date)
					end
				rescue OperationNotPermittedError
					return create_error_page(401, "operation not permitted")
				end
			end.keys
			case
			when page.status == 401 && !page.error_handled
				create_error_page(401, page.auth_reason)
			when page.status == 404 && !page.error_handled
				@config.cache.store_link(cache_name, "weberror/404", tags) if page.cachable
				create_error_page(404)
			when page.status == 304 && !page.error_handled
				return "Status: 304\n\n"
			when WebRedirect === page && !page.error_handled
				location= page.location.sub(/^\//, "")
				location=~ /\?/
				path= $` || location
				args= self.class.parse_get($' || "")
				@config.cache.store_link(cache_name, "web/#{@config.datasource.user.username}/#{path.dir_encode}?#{args.dir_encode}", tags, page.date)
				create_page(path, args)
			when (not page.cachable)
				page.to_output
			else
				res= page.to_output
				@config.cache.store(cache_name, res, tags)
				res
			end
		end

		def create_error_page(error, args= nil)
			cache_name= "weberror/#{error}"
			cache_name+= "/#{args.dir_encode}" if args
			res= @config.cache.retrieve(cache_name, IO)
			return res if res
			page= nil
			tags= @config.datasource.count do
				page= case error
				when 404
					Web404Page.new(config)
				when 401
					Web401Page.new(config, args)
				else
					NotImplemntedError
				end
			end.keys
			res= page.to_output
			@config.cache.store(cache_name, res, tags) if page.cachable
			res
		end

		def page_switch(direction, args, date= nil)
			case
			when direction == []
				WebRedirect.new(config, "/search", true)
			when direction == ["add"]
				WebAddPage.new(config)
			when direction == ["sourcecode"]
				WebSourceCode.new(config)
			when direction == ["login"]
				WebLogin.new(config)
			when direction == ["tags"]
				WebTagsPage.new(config)
			when ([["search"], ["downloadlist"]].include?(direction) and (args.keys - ["tags", "newtags", "rules"]).empty?)
				tags= (args["tags"] || "").split(" ")
				tags+= (args["newtags"] || "").split(" ")

				# Create the rule, in case the
				# user gave one.
				rule= nil
				rule= args["rules"].split("\n") if args["rules"]
				rule= Rule.from_string(rule) if rule

				case direction[0]
				when "search"
					if (args["newtags"])
						WebRedirect.new(config, WebSearchPage.url(tags, rule), true)
					else
						WebSearchPage.new(config, tags, rule)
					end
				when "downloadlist"
					WebDownLoadList.new(config, tags, rule)
				end
			when (["feed", "createfeed"].include?(direction[0]) and (args.keys - ["tags", "action", "age", "file_create", "file_update", "file_replace", "file_remove"]).empty?)
				tags= (args["tags"] || "").split(" ")
				action= (args["action"] || "").split(" ")
				action<< "file_create" if args["file_create"]
				action<< "file_update" if args["file_update"]
				action<< "file_replace" if args["file_replace"]
				action<< "file_remove" if args["file_remove"]
				if (action - ["file_create", "file_update", "file_replace", "file_remove", "user_create", "user_update"]).size > 0
					return Web404Page.new(config)
				end
				age= if args["age"]
					unless args["age"]=~ /^[1-7]$/
						return Web404Page.new(config)
					end
					args["age"].to_i
				else
					7
				end
				case direction[0]
				when "feed"
					WebFeed.new(config, tags, action, age)
				when "createfeed"
					WebCreateFeedPage.new(config, tags, action, age)
				end
			when (direction.size == 3 and ["files", "fileinfo", "update", "remove"].include?(direction[0]))
				WebRedirect.new(config, "/#{direction[0].uri_encode}/#{direction[1].uri_encode}")
			when (direction.size == 2 and direction[0] == "files")
				WebFile.new(config, direction[1], date)
			when (direction.size == 2 and direction[0] == "fileinfo")
				WebFileInfoPage.new(config, direction[1])
			when (direction.size == 2 and direction[0] == "update")
				WebUpdatePage.new(config, direction[1])
			when (direction.size == 2 and direction[0] == "remove")
				WebRemovePage.new(config, direction[1])
			when (direction[0] == "classic" and (args.keys - ["tags"]).size == 0)
				redirect= false
				path= @config.datasource.optimize_search(direction[1..-1])
				redirect= true if path != direction[1..-1]
				tags= nil
				if args["tags"]
					raw= args["tags"].split(" ")
					tags= @config.datasource.optimize_search(raw)
					redirect= true if raw != tags
				end
				if redirect
					WebRedirect.new(config, "/classic" + WebClassicPage.url(path, tags))
				else
					WebClassicPage.new(config, direction[1..-1], tags)
				end
			else
				Web404Page.new(config)
			end
		end

		def page_input_switch(direction, input, type, date)
			args= case type
			when "application/x-www-form-urlencoded"
				self.class.parse_get(input.read)
			when /^multipart\/form-data;\s+boundary=(.+)$/
				self.class.parse_multipart_formdata(input, "--" + $1)
			else
				Hash.new
			end
			files= args.values.grep(File)
			begin
				res= case
				when (direction == ["add"] and (args.keys - ["filename", "tags", "date", "source", "filedata", "groups"]).empty?)
					WebAddPage.new(config, args)
				when ((2..3) === direction.size and direction[0] == "update" and (args.keys - ["filename", "tags", "time", "source", "filedata", "groups"]).empty?)
					WebUpdatePage.new(config, direction[1], args)
				when ((2..3) === direction.size and direction[0] == "remove" and args == { "sure" => "true" })
					WebRemovedPage.new(config, direction[1])
				else
					Web404Page.new(config)
				end
			ensure
				files.each do |file|
					FileUtils.rm(file.path)
				end
			end
			return res
		end

		# Parses the extra information in an http var.
		# example: "Content-Disposition: form-data; name=filedata; filname=example.pdf
		# the extra data is the one after the first ; 
		# You may only provide this data.
		def self.parse_http_var_extra(data)
			res= Hash.new
			data.split(";").each do |arg|
				arg=~ /^\s*(\w+)=["'](.*?)["']$/
				res[$1]= $2
			end
			res
		end

		def self.read_until_delimiter(io, delimiter)
			data= ""
			delimiter= "\n" + delimiter
			loop do
				input= io.read(delimiter.size+1)
				while input=~ /\r/
					data+= $`
					input= $'
					if input == delimiter[0,input.size]
						x= io.read(delimiter.size-input.size)
						return data if x == delimiter[input.size..-1]
						input+= x
					end
						data+= "\r"
				end
				data+= input
			end
		end

		def self.parse_multipart_formdata(io, delimiter)
			res= Hash.new
			io.find { |line| line == delimiter + "\r\n" }
			loop do
				header= nil
				io.each do |line|
					line.strip!
					break if line.empty?
					header= self.parse_http_var_extra($') if line=~ /^Content-Disposition:\s+form-data;/
				end
				res[header["name"]]= if header["filename"]
					file= File.mktemp
					read_until_delimiter_io(io, file, delimiter)
					file.seek(0)
					file
				else
					self.read_until_delimiter(io, delimiter)
				end
				return res unless io.read(2) == "\r\n"
			end
		end

	end

end
