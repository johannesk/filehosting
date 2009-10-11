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
	# to it. The announced arguments are types as in Typiefieng.
	module MethodAnnouncing

		# Returns an array of all announced methods.
		def announced_methods
			announced_methods_var.keys
		end

		# Returns whether this method in an announced method.
		def method_announced?(method)
			announced_methods_var[method] and true
		end

		# Returns whether this method has announced
		# side effects.
		def sideeffect_announced?(method)
			announced_sideeffects_var[method]
		end

		# Returns all possibilities of arguments to supply to
		# an announced method when calling it. This is
		# returned as an array of array's. Each array is one
		# set of possible arguments.
		def method_args(method)
			announced_methods_var[method]
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
			announced_methods_var[method]= args
			class_variable_set(:@@announced_last, method)
		end
		protected :announce_method

		# Announces that a method has side effects. If no
		# method is specified, this is the last method.
		def announce_sideeffect(method= announced_last)
			raise "a non existing method can not have sideeffects: #{method}" unless self.method_defined?(method)
			announced_sideeffects_var[method]= true
		end
		protected :announce_sideeffect

		def announced_methods_var
			unless class_variable_defined?(:@@announced_methods)
				class_variable_set(:@@announced_methods, Hash.new)
			end
			class_variable_get(:@@announced_methods)
		end
		private :announced_methods_var

		def announced_sideeffects_var
			unless class_variable_defined?(:@@announced_sideeffects)
				class_variable_set(:@@announced_sideeffects, Hash.new(false))
			end
			class_variable_get(:@@announced_sideeffects)
		end
		private :announced_sideeffects_var

		def announced_last
			class_variable_get(:@@announced_last)
		end

	end

end

