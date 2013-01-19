require File.expand_path('../../../test_helper', __FILE__)

class PathogenParserTest < Riml::TestCase
  test "parses without error" do
    source = File.read File.expand_path("../pathogen.riml", __FILE__)
    assert parse(source)
  end

  test "gives proper lineno when raises parse error" do
    source = File.read(File.expand_path("../pathogen.riml", __FILE__)) + "\nparseError!!!!jfkds"
    lineno = source.each_line.to_a.size
    error  = nil
    begin
      parse(source)
    rescue Riml::ParseError => e
      error = e
    end
    assert error
    assert error.message =~ /line #{Regexp.escape(lineno.to_s)}\b/
  end
end
