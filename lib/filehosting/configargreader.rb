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

require "filehosting/configreader"

module FileHosting

	# A Class to read a config from a file
	class ConfigArgReader < ConfigReader

		attr :values

		def initialize
			@values= Hash.new
		end

		def parse(args)
			m= methods.grep(/^arg_/).collect { |a| a[4..-1] }
			args= self.class.split_shortarg(args)
			while args.size > 0
				break unless args[0]=~ /^--?(\w+)$/
				arg= args.shift
				arg_help unless m.include?($1)
				block= method("arg_#{$1}")
				a= []
				block.arity.times { a << args.shift }
				block.call(*a)
			end
			args
		end

		def self.split_shortarg(args)
			args= args.collect do |arg|
				next arg unless arg=~ /^-\w+$/
				arg[1..-1].split(//).collect { |a| "-#{a}" }
			end.flatten
		end

		def usage
			args_m= []
			args= []
			methods.grep(/^arg_/).each do |m|
				if args_m.include?(method(m))
					args[args_m.index(method(m))] << m[4..-1]
				else
					args_m<< method(m)
					args<< [m[4..-1]]
				end
			end
			args.each { |a| a.sort! { |a,b| a.size <=> b.size } }
			args.each { |a| a.unshift("") if a[0].size > 1 }
			max= Array.new(args.inject(0) { |n, a| n < a.size ? a.size : n }, 0)
			args.each do |a|
				a.size.times do |i|
					max[i]= a[i].size if a[i].size > max[i]
				end
			end
			messages= args.collect do |arg|
				argm= arg.collect do |s|
					case s.size
					when 0
						""
					when 1
						"-"
					else
						"--"
					end +
					s
				end
				"    " +
				(0..(arg.size-1)).collect do |i|
					argm[i]+" "*(max[i]+3-argm[i].size)
				end.join +
				"     " +
				arg.collect do |s|
					eval("help_#{s}") if methods.include?("help_#{s}")
				end.find { |x| x }
			end
			banner+"\n" + messages.join("\n")
		end

		def banner
			"usage: #{$0} [options]"
		end

		def help_help
			"display this message"
		end

		def arg_help
			puts usage
			exit 0
		end

		def help_human
			"human readable"
		end

		def arg_human
			@values[:human]= true
		end
		alias :arg_h :arg_human

		def read
			@values
		end

	end

end

