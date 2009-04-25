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
require "filehosting/string"
require "filehosting/yaml"

module FileHosting

	class Rule
		
		include YAMLPropertiesByEval

		attr_accessor :result
		attr_accessor :conditions

		def initialize(result= nil, conditions= [])
			@result= result
			@conditions= conditions
		end

		def add_condition(a, test, b)
			@conditions<< [a, test, b]
		end

		def add_raw(raw)
			if raw=~ /^\s*([^\s]+)\s+([^\s]+)\s+([^\s]+)\s*$/
				add_condition($1, $2, $3)
			else
				raise RuleEvalError.new(raw)
			end
		end

		def test(data)
			@conditions.each do |a, test, b|
				return @nil unless test_condition(parse_operand(a, data), test, parse_operand(b, data))
			end
			return @result
		end

		def parse_operand(operand, data)
			case operand
			when /^(\w+)((\.\w+)+)$/
				op= $2[1..-1]
				res= data[$1]
				raise RuleOperandError.new(operand) unless res
				while op=~ /^(\w+)((\.\w+)*)$/
					op= $2[1..-1] || ""
					bl= res.rule_operand[$1]
					raise RuleOperandError.new(operand) unless bl
					res= bl.call
				end
				res
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

		def to_s
			"#{@result} if #{@conditions.collect { |a, test, b| "#{a} #{test} #{b}" }.join(" and ")}"
		end
		alias :to_text :to_s

		def ==(other)
			@result == other.result and
			@conditions.sort == other.conditions.sort
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
				when "!~"
					!(data =~ operand)
				when ">"
					data > operand
				when "<"
					data < operand
				when "<="
					data <= operand
				when ">="
					data >= operand
				when "includes"
					data.include?(operand)
				when "!includes"
					!data.include?(operand)
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
		res.result= value["result"]
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

class Object

	def rule_operand
		Hash.new
	end

end

class Array

	def rule_operand
		{
			"size" => lambda { size }
		}
	end

end

class String

	def rule_operand
		{
			"size" => lambda { size }
		}
	end

end

