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

	# MethodAnnouncing is a framework to announce methods. It's
	# purpose is to allow method calling without prior knowledge
	# of which methods are available and which arguments to supply
	# to it.
	#
	# == Arguments
	#
	# In a set of arguments each arguments has the following
	# meaning:
	# - Class: an object of this class
	# - [Class]: an array of objects of this class
	# - [a, b, c]: on of the members of this array
	# - (a..b): an object in this range.
	# - (Integer..Integer): if first or last in range is an integer the object must be an integer
	module MethodAnnouncing

		# Returns an array of all announced methods.
		def announced_methods
			(@announced_methods or Hash.new).keys
		end

		# Returns whether this method in an announced method.
		def method_announced?(method)
			(@announced_methods or Hash.new)[method] and true
		end

		# Returns all possibilities of arguments to supply to
		# an announced method when calling it. This is
		# returned as an array of array's. Each array is one
		# set of possible arguments.
		def method_args(method)
			(@announced_methods or Hash.new)[method]
		end
	
		# Announces a method. Args are sets of possible
		# arguments.
		def announce_method(method, *args)
			raise "a non existing method can not be announced: #{method}" unless self.method_defined?(method)
			# ensure all arg possibilities are arrays
			args.collect! { |x| Array === x ? x : [x] }
			# if no set of arguments is given assume the
			# empty set was meant.
			args= [[]] if args.size == 0
			@announced_methods= Hash.new unless @announced_methods
			@announced_methods[method]= args
		end
		protected :announce_method

	end

end

