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

require "pathname"

module FileHosting

	autoload  :InternalDataCorruptionError, "filehosting/internaldatacorruptionerror"
	autoload  :CircularDependencyError, "filehosting/circulardependencyerror"

	# All available parts should be marked for autoloading here.
	# So they can be used everywhere with use_part.
	autoload :WebFileInfoPart, "filehosting/webfileinfopart"
	autoload :WebFileInfoButtonPart, "filehosting/webfileinfobuttonpart"
	autoload :WebUpdateButtonPart, "filehosting/webupdatebuttonpart"
	autoload :WebRemoveButtonPart, "filehosting/webremovebuttonpart"
	autoload :WebFileHistoryButtonPart, "filehosting/webfilehistorybuttonpart"
	autoload :WebTagSearchPart, "filehosting/webtagsearchpart"
	autoload :WebSearchBoxPart, "filehosting/websearchboxpart"
	autoload :WebTagInputPart, "filehosting/webtaginputpart"

	# This module can be included to be able to specify file
	# inclusions for webpages, webparts, ... . Included files can
	# have dependencies. Circular dependencies are not allowed.
	module WebDependencies

		DependencyPath= Pathname.new("web/deps")

		# Marks a file for web inclusion. All Dependencies of
		# this file will also be marked.
		def use(file)
			file= dep_path(file)
			# we need the full path
			var= webdependencies
			# only if not already included
			unless var.include?(file)
				use_raw(get_deps(file) + [file])
			end
		end

		# Marks a file or multiple files for web inclusion.
		# The files must be specified by their path. No
		# dependencies will be evaluated. Other methods
		# assume all dependencies are evaluated, so make sure
		# to only use use_raw when to dependency evaluation
		# is needed.
		def use_raw(*files)
			var= webdependencies
			var.push(*files.flatten)
		end

		# Returns an array of all dependencies for this file.
		# Throws an exception on circular dependencies.
		def get_deps(files)
			files= [files].flatten
			file= files[-1]

			direct_deps(file).collect do |dep|
				# check for circular dependency
				if files.include?(dep)
					raise CircularDependencyError.new(files + [dep])
				end

				get_deps(files+[dep])+[dep]
			end.flatten.uniq
		end

		# Dependencies are specified by only their name. But
		# they are handled always by the full path. This
		# methods creates the full path from a name. For
		# example "default.css" => "/style/default.css".
		def dep_path(dep)
			case dep
			when /\.css$/
				"style/#{dep}"
			when /\.js$/
				"js/#{dep}"
			else
				raise NotImplementedError
			end
		end

		# Returns an array of all marked files.
		def webdependencies
			unless instance_variable_defined?(:@webdependencies)
				instance_variable_set(:@webdependencies, [])
			end
			instance_variable_get(:@webdependencies)
		end

		# Returns an array of direct dependencies for a file.
		def direct_deps(file)
			file= DependencyPath + file
			# no direct deps if no file
			return [] unless file.file?

			res= file.read.collect { |dep| dep_path(dep.strip) }
			res
		end

		# Uses a webpart. Returns it's body and registers it's
		# dependencies.
		def use_part(partclass, *args)
			begin
				part= if block_given?
					partclass.new(config, *args) { |*x| yield(*x) }
				else
					partclass.new(config, *args)
				end
			rescue ArgumentError
				raise "wrong arguments for '#{partclass}': '#{args.inspect}'"
			end
			use_raw(part.webdependencies)
			part.body
		end


	end

end
