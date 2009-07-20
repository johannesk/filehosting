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

require "filehosting/mirrorplugin"
require "filehosting/yamltools"
require "filehosting/fileinfo"
require "filehosting/file"
require "filehosting/array"
require "filehosting/string"

require "erb"
require "pathname"
require "net/http"
require "uri"
require "uuidtools"

module FileHosting

	autoload :InternalDataCorruptionError, "filehosting/internaldatacorruptionerror"

	class HTTPMirror < MirrorPlugin

		def initialize(config)
			@config= config
			@pages= Hash.new
		end

		# make a http get and returns the body as string on
		# success
		def read(url)
			found= @pages[url]
			return found if found
			url= URI.prase(url) unless URI === url
			res= Net::HTTP.get_response(url)
			case res
			when Net::HTTPSuccess
				@pages[url]= res.body
				res.body
			else
				nil
			end
		end

		# Finds all url's enclosed in <a href="URL">, from an
		# url. If pattern is giving only those matching that
		# pattern.
		def find_urls(url, pattern= nil)
			url= URI.parse(url) unless URI === url
			body= read(url)
			res= []
			return res unless body
			body=~ /^/
			while $'=~ /<a(\s+\w+=['"][^'"]*['"])*\s+href=['"]([^'"]+)['"](\s+\w+=['"][^"]*['"])*\s*>/
				begin
					link= url + URI.parse($2)
				rescue URI::InvalidURIError
				else
					res<< link
				end
			end
			res.select { |l| l.to_s=~ pattern }
		end

		# loads a file from a url and creates a fileinfo
		# returns it's filedata
		# returns false if the file can not be downloaded
		def create_file(url)
			file= FileInfo.new
			file.source= url.to_s
			file.filename= Pathname.new(url.path).basename.to_s.uri_decode
			Net::HTTP.get_response(url) do |res|
				case res
				when Net::HTTPSuccess
					if res["Last-Modified"]
						begin
							file.user_time= Time.httpdate(res["Last-Modified"])
						rescue ArgumentError
							return nil
						end
						return [file, res.read_body]
					end
					return false
				else
					return false
				end
			end
		end

		# try's to update a file via http
		# returns false if no update was found
		# returns the new filedata if file was updated
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
						file.user_time= time
						return res.read_body
					else
						return false
					end
				else
					return false
				end
			end
		end

		def check_new(location, files)
			result= []
			begin
				url= URI.parse(location.location)
			rescue URI::InvalidURIError
				raise InternalDataCorruptionError
			end
			old_urls= files.values.collect do |fileinfo, data|
				raise InternalDataCorruptionError unless String === data
				begin
					URI.parse(data)
				rescue URI::InvalidURIError
					raise InternalDataCorruptionError
				end
			end
			new_urls= find_urls(url, location.pattern) - old_urls
			new_urls.each do |url|
				fileinfo, filedata= create_file(url)
				if fileinfo and filedata
					result<< [fileinfo, filedata, url.to_s, url.to_s]
					notify_observers(:create, url.to_s ,fileinfo.uuid)
				end
			end
			result
		end

		def check_update(files)
			result= []
			files.values.each do |fileinfo, data|
				raise InternalDataCorruptionError unless String === data
				begin
					url= URI.parse(data)
				rescue URI::InvalidURIError
					raise InternalDataCorruptionError
				end
				if filedata= update_file(fileinfo, url)
					result<< [fileinfo, filedata, data, data]
					notify_observers(:update, data, fileinfo.uuid)
				end
			end
			result
		end

	end

end
