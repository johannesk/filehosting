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

require "filehosting/ruleevalerror"
require "filehosting/ruleoperanderror"
require "filehosting/rulewhaterror"
require "filehosting/string"
require "filehosting/yaml"

module FileHosting

	class Rule
		
		include YAMLPropertiesByEval

		attr :result
		attr :conditions

		def initialize(result= nil, conditions= [])
			@result= result
			@conditions= conditions
		end

		def add_condition(what, test, operand)
			@conditions<< [what, test, operand]
		end

		def add_raw(raw)
			if raw=~ /^\s*([^\s]+)\s+([^\s]+)\s+(.*?[^\s])\s*$/
				add_condition($1, $2, parse_operand($3))
			else
				raise RuleEvalError.new(raw)
			end
		end

		def test(data)
			@conditions.each do |what, test, operand|
				return @nil unless test_condition(parse_data(what, data), test, operand)
			end
			return @result
		end

		def parse_data(what, data)
			case what
			when "fileinfo.uuid"
				data[:fileinfo].uuid.to_s
			when "fileinfo.filename"
				data[:fileinfo].filename
			when "fileinfo.mimetype"
				data[:fileinfo].mimetype
			when "fileinfo.size"
				data[:fileinfo].size
			when "fileinfo.hash_type"
				data[:fileinfo].hash_type
			when "fileinfo.hash"
				data[:fileinfo].hash
			when "fileinfo.tags"
				data[:fileinfo].tags
			when "fileinfo.source"
				data[:fileinfo].source
			else
				raise RuleWhatError.new(what)
			end
		end

		def parse_operand(operand)
			case operand
			when /^\d+$/
				operand.to_i
			when /^(\d+)([,.](\d*))?([kmgtpKMGTP])$/
				postfix= $4
				(operand.sub(",", ".").to_f * 1024**(["K", "M", "G", "T", "P"].index(postfix.upcase)+1)).round
			when /^\/(.*?)\/$/
				/#{$1.user_decode}/
			when /^"(.*?)"/
				$1.user_decode
			else
				raise RuleOperandError.new(operand)
			end
		end

		def test_condition(data, test, operand)
			begin
				case test
				when "=="
					data == operand
				when "!="
					data != operand
				when "=~"
					data =~ operand
				when ">"
					data > operand
				when "<"
					data < operand
				when "<="
					data <= operand
				when ">="
					data >= operand
				when "includes"
					data.include? operand
				else
					raise "can not execute '#{test}'"
				end
			rescue Exception => e
				raise RuleEvalError.new("#{data.inspect} #{test} #{operand.inspect}", e)
			end
		end

		# all subclasses of FileInfo should only serialize FileInfo Attributes
		def to_yaml_properties
			{
				"result"     => lambda { @result },
				"conditions" => lambda { @conditions }
			}
		end

		def to_yaml_type
			"!filehosting/rule"
		end

	end

end

YAML.add_domain_type("filehosting.yaml.org,2002", "rule") do |tag, value|
	begin
		res= FileHosting::Rule.new
		res.result= value["result"].to_s
		res.conditions= value["conditions"].collect do |con|
			raise FileHosting::InternalDataCorruptionError unless con.size == 3
			con.collect do |s|
				s.to_s
			end
		end
		res
	rescue
		raise FileHosting::InternalDataCorruptionError
	end
end


