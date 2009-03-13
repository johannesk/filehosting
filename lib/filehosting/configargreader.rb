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
			m= switches
			args= self.class.split_shortarg(args)
			while args.size > 0
				break unless args[0]=~ /^--?(\w+)$/
				arg= args.shift
				switch_help unless m.include?(arg)
				block= method("switch_#{$1}")
				a= []
				block.arity.times { a << args.shift }
				block.call(*a)
			end
			args
		end

		# converts ["-abc"] into ["-a", "-b", "-c"]
		def self.split_shortarg(args)
			args= args.collect do |arg|
				next arg unless arg=~ /^-\w+$/
				arg[1..-1].split(//).collect { |a| "-#{a}" }
			end.flatten
		end

		# all available switches
		def switches
			m= methods.grep(/^switch_/)
			m= m.collect { |a| a[("switch_".size)..-1] }
			m= m.collect do |a|
				if a.size == 1
					"-#{a}"
				else
					"--#{a}"
				end
			end
		end

		# all available switches. Multiple represantations of
		# the same switch are grouped together
		# example: [["-h", "--human"], ["--help"]]
		def switchGroups
			meth= []
			res= []
			switches.each do |s|
				s=~ /^--?(\w+)$/
				m= method("switch_#{$1}")
				if meth.include?(m)
					res[meth.index(m)] << s
				else
					meth<< m
					res<< [s]
				end
			end
			res.each { |a| a.sort! { |a,b| a.size <=> b.size } }
			res
		end

		# returns the usage string as seen in --help
		def usage
			sg= switchGroups
			sg.each { |a| a.unshift("") if a[0].size > 2 } # leave the first column empty if no short option is given
			max= Array.new(sg.inject(0) { |m, a| m < a.size ? a.size : m }, 0)
			sg.each do |a|
				a.size.times do |i|
					max[i]= a[i].size if a[i].size > max[i]
				end
			end
			messages= sg.collect do |arg|
				"    " +
				(0..(arg.size-1)).collect do |i|
					arg[i]+" "*(max[i]+2-arg[i].size)
				end.join +
				"     " +
				arg.collect do |s|
					s=~ /^--?(\w+)$/
					eval("help_#{$1}") if methods.include?("help_#{$1}")
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

		def switch_help
			puts usage
			exit 0
		end

		def help_human
			"human readable"
		end

		def switch_human
			@values[:human]= true
		end
		alias :switch_h :switch_human

		def read
			@values
		end

	end

end

