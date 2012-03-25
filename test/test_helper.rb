#!/usr/bin/env ruby

require File.join(File.expand_path(File.dirname(__FILE__) + '/..'), "config/environment")

require 'minitest/autorun'
require 'active_support/all'

module Riml
  class TestCase < ::ActiveSupport::TestCase
    def lex(code)
      @tokens = @lexer.tokenize(code)
    end

    def parse(code)
      @parser.parse(code)
    end

    def compile(code)
      @compiler.compile(code)
    end
  end
end
