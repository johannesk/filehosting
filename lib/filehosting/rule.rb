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

require "filehosting/string"
require "filehosting/yaml"
require "filehosting/ruleoperanddatamissingerror.rb"

module FileHosting

	autoload :RuleEvalError, "filehosting/ruleevalerror"
	autoload :RuleParseError, "filehosting/ruleparseerror"
	autoload :RuleOperandError, "filehosting/ruleoperanderror"

	class Rule
		
		include Enumerable
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
				raise RuleParseError.new(self, raw)
			end
		end

		# Returns a new rule where everything which can
		# already be evaluated, doesn't need to be evaluated
		# again.
		def prepare(data)
			res= Rule.new(@result)
			each do |a, test, b|
				begin
					# all conditions are "and"
					# related if one conditios is
					# false: we can return the
					#        empty rule
					# true:  we don't need this
					#        condition
					return Rule.new(nil) unless test_condition(parse_operand(a, data), test, parse_operand(b, data))
				rescue RuleOperandDataMissingError
					# the condition needs to be
					# evaluated later, when all
					# data is available
					res.add_condition(a, test, b)
				end
			end
			res
		end

		def test(data)
			each do |a, test, b|
				return @nil unless test_condition(parse_operand(a, data), test, parse_operand(b, data))
			end
			return @result
		end

		def parse_operand(operand, data)
			case operand
			when /^(\w+)((\.\w+)+)$/
				op= $2[1..-1]
				res= data[$1]
				raise RuleOperandDataMissingError.new(self, operand) unless res
				while op=~ /^(\w+)((\.\w+)*)$/
					op= $2[1..-1] || ""
					bl= res.rule_operand[$1]
					raise RuleOperandError.new(self, operand) unless bl
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
				raise RuleOperandError.new(self, operand)
			end
		end

		def self.from_string(string)
			rule= Rule.new(true)
			string.each do |r|
				next if r.strip.empty?
				rule.add_raw(r)
			end
			rule
		end

		def to_a
			@conditions
		end

		def each(&block)
			to_a.each do |a, test, b|
				block.call(a, test, b)
			end
		end

		# Each but in raw string presentation rather than in
		# [a, test, b] presentation.
		def each_raw(&block)
			each do |a, test, b|
				block.call("#{a} #{test} #{b}")
			end
		end

		def to_s
			"#{@result} if #{collect { |a, test, b| "#{a} #{test} #{b}" }.join(" and ")}"
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
				raise RuleEvalError.new(self, "#{data.inspect} #{test} #{operand.inspect}", e)
			end
		end

		# all subclasses of Rule should only serialize Rule
		# Attributes
		def to_yaml_hash
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

