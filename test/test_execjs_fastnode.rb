require 'test_helper'

class TestExecJSFastNode < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::ExecJS::FastNode::VERSION
  end
end
