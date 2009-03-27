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

require "filehosting/webpage"

module FileHosting

	# The sourcecode webpage
	class WepSourceCode < WepPage

		def initialize(config)
			super(config)
			@header["Content-Type"]= "application/x-tar"
			@header["Content-Disposition"]= "attachment;filename=filehosting-snapshot.tar"
		end

		def body
			root= Pathname.new("root")
			ignore= YAMLTools.read_array(root + ".ignore", Regexp)
			io= IO.popen("tar -c -C root -T -", "r+")
			todo= []
			todo<< root
			until todo.empty?
				todo.shift.children.each do |child|
					rel= child.relative_path_from(root).to_s
					case
					when ignore.find { |reg| rel=~ reg }
					when child.symlink?
						io.puts rel
					when child.directory?
						todo<< child
					else
						io.puts rel
					end
				end
			end
			io.close_write
			io
		end

	end

end

