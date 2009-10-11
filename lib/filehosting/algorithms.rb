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

	# A collection of algorithms
	module Algorithms

		# Computes the did you mean distance between two
		# strings. If the longest common subsequence (lcs)
		# contains adjacent characters which where adjacent in
		# the original strings, the distance will be lowered.
		# If between two in the lcs adjacent character, or the
		# beginning of the lcs and the first character, or the
		# last character of the lcs and the end of the string,
		# are other characters in the original strings, the
		# distance will be raised. This is computed for every
		# possible lcs (the lcs is not unique). The lowest
		# distance found for an lcs is taken as the original
		# strings distance.
		def self.did_you_mean_distance(a, b)
			a= a.downcase
			b= b.downcase
			lcs(a, b).collect do |lcs|
				res= 0
				(lcs.size-1).times do |i|
				# find all character which are
				# adjacent in the lcs and the original
				# strings
					res-= 2 if lcs[i][0]+1 == lcs[i+1][0] and lcs[i][1]+1 == lcs[i+1][1]
				end
				lcs2= [[-1, -1]] + lcs + [[a.size, b.size]]
				(lcs.size+1).times do |i|
				# calculate whether between two in the
				# lcs adjacent characters are
				# characters in the original strings
					u1= lcs2[i][0]+1 - lcs2[i+1][0]
					u2= lcs2[i][1]+1 - lcs2[i+1][1]
					res+= case
					when u1 == 0 && u2 == 0
					# no characters between
						0
					when u1 == 0 || u2 == 0
					# characters between in one
					# string
						1
					else
					# characters between in both
					# strings
						2
					end
				end
				res
			end.min
		end

		# Returns all possibilities for the lcs of the two
		# strings a and b. The lcs is returned as an array of
		# positions in both strings.
		# ex. "abc", "12b3" a possible lcs is "b" which will
		# be returned as [[1,2]] which means it consists of
		# the character which can be found at "abc"[1] and
		# "12b3[2]
		def self.lcs(a, b)
			# the lcs for a[0..i], "" is ""
			arr= Array.new(a.size + 1, [[]])
			1.upto(b.size) do |ii|
				tmp= [[]]
				1.upto(a.size) do |i|
				# calculate the lcs for a[0..i], b[0..ii]
					v= arr[i]
					case v[0].size <=> (arr[i-1][0].size)
					when -1
						v= arr[i-1]
					when 0
						v= (v + arr[i-1]).uniq
					end
					if a[i-1] == b[ii-1]
					# we found a common character
						case v[0].size <=> (tmp[0].size + 1)
						when -1
							v= tmp.collect { |ar| ar + [[i-1, ii-1]] }
						when 0
							v= (v + tmp.collect { |ar| ar + [[i-1, ii-1]] }).uniq
						end
					end
					tmp= arr[i]
					arr[i]= v
				end
			end
			arr[a.size]
		end

	end

end

