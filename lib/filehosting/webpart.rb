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

module FileHosting

	# A part of a webpage
	class WebPart

		attr_reader :config
		attr_reader :body
		attr_reader :tags

		def initialize(config, name, &block)
			@config= config
			name= "webpart/#{config.datasource.user.username}/#{name}"
			@body= @config.cache.retrieve(name) if cachable
			if @body
				@tags= @config.cache.tags(name)
			else
				@body, tags= yield
				@tags= ((@tags || []) + tags).uniq
				@config.cache.store(name, @body, @tags) if cachable
			end
		end

		def use_part(partclass, *args)
			begin
				part= partclass.new(config, *args)
			rescue ArgumentError
				raise "wrong arguments for '#{partclass}': '#{args.inspect}'"
			end
			@tags= [] unless @tags
			@tags= (@tags+part.tags).uniq
			part.body
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
			datasource.user
		end

	end

end

