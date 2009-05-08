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
require "filehosting/array"
require "filehosting/string"

require "erb"
require "pathname"
require "net/http"
require "uri"
require "uuidtools"
require "observer"

module FileHosting

	autoload :InternalDataCorruptionError, "filehosting/internaldatacorruptionerror"

	class HTTPMirror

		include Observable

		def notify_observers(*args)
			changed
			super(*args)
			@pages= Hash.new
		end

		# make a http get and returns the body as string on
		# success
		def self.read(url)
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
		def self.find_urls(url, pattern= nil)
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
			res= res.find_all { |link| link.to_s=~ pattern } if pattern
			res
		end

		def initialize(config)
			@config= config
			@storage= config.storage.prefix("httpmirror")
		end

		def register(name, url, pattern, tags, source= nil)
			list= url_list(name)
			list<< [url, pattern, tags, source]
			store_url_list(name, list)
		end

		def remove(name, url, pattern)
			list= url_list(name)
			list.delete_if do |turl, tpattern|
				url == turl and pattern == tpattern
			end
			store_url_list(name, list)
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
						notify_observers(:update, url, file.uuid)
					end
				end
			end
		end

		def update(name)
			filelist= file_list(name)
			urllist= url_list(name)
			new= urllist.collect do |url, pattern, tags, source|
				self.class.find_urls(url, pattern).collect do |x|
					[x, tags, source]
				end
			end.flatten(1)
			new.delete_if { |url, tags, source| filelist.find { |oldurl, file| oldurl == url } }
			tmplist= []
			new.delete_if { |url, tags, source| tmplist.include?(url) ? true : (tmplist << url; false) }
			filelist.each do |url, file|
				update_file(file, url)
			end
			begin
				new.each do |url, tags, source|
					uuid= create_file(url, tags, source)
					filelist<< [url, uuid] if uuid
				end
			ensure
				store_file_list(name, filelist)
			end
		end

		# loads a file from a url and stores it into the
		# datasource. Returns the uuid
		def create_file(url, tags, source= nil)
			file= FileInfo.new
			file.source= source || url.to_s
			file.filename= Pathname.new(url.path).basename.to_s.uri_decode
			file.tags= tags
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
						notify_observers(:create, url, file.uuid)
						ret= file.uuid
					end
				end
			end
			ret
		end

		def url_list(name)
			list= @storage.read(url_list_name(name))
			return [] unless list
			list= YAMLTools.parse_array(list, Array)
			list.collect do |a|
				raise IntenralDataCorruption unless a.size == 4
				begin
					url= URI.parse(a[0])
				rescue ArgumentError
					raise IntenralDataCorruption
				end
				raise IntenralDataCorruption unless Regexp === a[1]
				pattern= a[1]
				raise IntenralDataCorruption unless Array === a[2]
				tags= a[2].collect { |x| x.to_s }
				source= a[3]
				source.to_s unless source.nil?
				[url, pattern, tags, source]
			end
		end

		def file_list(name)
			list= @storage.read(file_list_name(name))
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

		def store_file_list(name, list)
			name= file_list_name(name)
			if list.size == 0
				@storage.remove(name)
			else
				@storage.store_data(name, list.collect { |url, uuid| [url.to_s, uuid.uuid.to_s] }.to_yaml)
			end
		end

		def store_url_list(name, list)
			name= url_list_name(name)
			if list.size == 0
				@storage.remove(name)
			else
				@storage.store_data(name, list.collect { |url, pattern, tags, source| [url.to_s, pattern, tags, source] }.to_yaml)
			end
		end

		def file_list_name(name)
			"filelist/#{name}"
		end

		def url_list_name(name)
			"urllist/#{name}"
		end

	end

end
