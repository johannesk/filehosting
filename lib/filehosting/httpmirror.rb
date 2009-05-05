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

require "filehosting/yamltools"
require "filehosting/fileinfo"
require "filehosting/file"

require "erb"
require "pathname"
require "net/http"
require "uri"
require "uuidtools"

module FileHosting

	autoload :InternalDataCorruptionError, "filehosting/internaldatacorruptionerror"

	class HTTPMirror

		# make a http get and returns the body as string on
		# success
		def self.read(url)
			url= URI.prase(url) unless URI === url
			res= Net::HTTP.get_response(url)
			case res
			when Net::HTTPSuccess
				res.body
			else
				nil
			end
		end

		# Finds all url's enclosed in <a href="URL">, from an
		# url. If pattern is giving only those matching that
		# pattern.
		def self.find_urls(url, pattern= nil)
			url= URI.parse(url) unless URI === url
			body= read(url)
			res= []
			return res unless body
			body=~ /^/
			while $'=~ /<a(\s+\w+="[^"]")*\s+href="([^"]+)"(\s+\w+="[^"]")*\s*>/
				begin
					link= url + URI.parse($2)
				rescue URI::InvalidURIError
				else
					res<< link
				end
			end
			res= res.find_all { |link| link.to_s=~ pattern } if pattern
			res
		end

		def initialize(config, name, tags, source= nil)
			@config= config
			@name= name
			@tags= tags
			@source= nil
			@storage= config.storage.prefix("httpmirror")
		end

		# try's to update a file via http
		def update_file(file, url)
			http= Net::HTTP.new(url.host, url.port)
			http.request_get(url.path, {"If-Modified-Since" => file.user_time.httpdate}) do |res|
				case res
				when Net::HTTPSuccess
					if res["Last-Modified"]
						begin
							time= Time.httpdate(res["Last-Modified"])
							return if time <= file.user_time
						rescue ArgumentError
							return nil
						end
						@config.datasource.update_filedata(file, res.read_body)
					end
				end
			end
		end

		def update(urls, pattern= nil)
			filelist= file_list
			new= [urls].flatten.collect { |url| self.class.find_urls(url, pattern) }.flatten
			new.delete_if { |url| filelist.find { |a| a[0] == url } }
			filelist.each do |url, file|
				update_file(file, url)
			end
			begin
				new.each do |url|
					uuid= create_file(url)
					filelist<< [url, uuid]
				end
			ensure
				store_file_list(filelist)
			end
		end

		# loads a file from a url and stores it into the
		# datasource. Returns the uuid
		def create_file(url)
			file= FileInfo.new
			file.source= @source || url.to_s
			file.filename= Pathname.new(url.path).basename
			file.tags= @tags
			ret= nil
			Net::HTTP.get_response(url) do |res|
				case res
				when Net::HTTPSuccess
					if res["Last-Modified"]
						begin
							file.user_time= Time.httpdate(res["Last-Modified"])
						rescue ArgumentError
							return nil
						end
						@config.datasource.add_file(file, res.read_body)
						ret= file.uuid
					end
				end
			end
			ret
		end

		def file_list
			list= @storage.read(@name)
			return [] unless list
			list= YAMLTools.parse_array(list, Array)
			list.collect do |a|
				raise IntenralDataCorruption unless a.size == 2
				begin
					url= URI.parse(a[0])
					uuid= UUID.parse(a[1])
				rescue ArgumentError
					raise IntenralDataCorruption
				end
				[url, @config.datasource.fileinfo(uuid)]
			end
		end

		def store_file_list(list)
			@storage.store_data(@name, list.collect { |url, uuid| [url.to_s, uuid.uuid.to_s] }.to_yaml)
		end

	end

end
