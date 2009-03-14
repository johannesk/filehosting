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

require "filehosting/fileinfo"

require "uuidtools"

module FileHosting

	# Sample FileInfo's can be genarated without a database or even existing files.
	class SampleFileInfo < FileInfo

		def initialize
			@uuid= UUID.random_create.to_s
			random= rand(3)
			@mimetype= ["application/pdf", "video/ms-xvideo", "text/x-c++"][random]
			@filename= ["Uebung"+rand(30).to_s+".pdf", "Vorlesung"+rand(30).to_s+".avi", "Programm"+rand(30).to_s+".java"][random]
			@source= "http://source.example/#{@filename}"
			@size= (rand*2**(rand*40)).to_i
			@tags= []
			@tags<< "#{(rand*2)<1 ? "S" : "W"}S#{rand(30)}"
			@tags+= [["Uebung"], ["Video", "Vorlesung"], ["Uebung", "Sourcecode"]][random]
			@history= []
		end

	end

end

