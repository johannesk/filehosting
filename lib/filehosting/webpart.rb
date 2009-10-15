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

require "filehosting/webdependencies"

autoload :YAML, "yaml"

module FileHosting

	autoload  :InternalDataCorruptionError, "filehosting/internaldatacorruptionerror"

	# A part of a webpage
	class WebPart

		include WebDependencies

		attr_reader :config
		attr_reader :body

		def initialize(config, name= nil)
			@config= config
			if (if cachable
				# cachable parts need a name to be stored in the cache
				if !name
					raise ArgumentError.new("a name must be given if webpart is cachable")
				end
				bodyname= "webpart/#{config.datasource.current_user.username}/#{name.dir_encode}/body"
				depsname= "webpart/#{config.datasource.current_user.username}/#{name.dir_encode}/deps"
				@body= config.cache.retrieve(name)
			end) and @body
			# if retrieved from cache
				# register cache tags
				config.datasource.register_op(config.cache.tags(bodyname))
				# register web dependencies
				use_raw(cached_dependencies(depsname))
			else
				unless @body
					raise ArgumentError.new("a block must be given if @body is not set") unless block_given?
					tags= config.datasource.count do
						@body= yield
					end.keys
				end
				if cachable
				# store in cache
					config.cache.store(bodyname, @body, tags)
					config.cache.store(depsname, webdependencies.join("\n"), tags)
				end
			end
		end

		# Retrieves dependencies from the cache
		def cached_dependencies(name)
			config.cache.retrive(name).collect { |dep| dep.strip }
		end

		def cachable
			true
		end

		def webroot
			config[:webroot]
		end

		def datasource
			config[:datasource]
		end

		def user
			datasource.current_user
		end

	end

end

