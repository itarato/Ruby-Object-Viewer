require_relative('data')
require_relative('../r_o_v')
require("minitest/autorun")

class MagicBallTest < Minitest::Test
  def setup
    @rov = ROV.new(Organism.new)
  end

  def test_default_var
    assert_equal("_.list", @rov.current_variable_as_expression)
  end

  def test_open_and_back
    assert_equal("_.list", @rov.current_variable_as_expression)

    @rov.execute('d')
    assert_equal("_.list[0]", @rov.current_variable_as_expression)

    @rov.execute('a')
    assert_equal("_.list", @rov.current_variable_as_expression)
  end

  def test_open_deep_and_back
    assert_equal("_.list", @rov.current_variable_as_expression)

    @rov.execute('d')
    @rov.execute('d')
    @rov.execute('s')
    @rov.execute('d')

    assert_equal("_.list[0].type.markers", @rov.current_variable_as_expression)

    @rov.execute('a')
    assert_equal("_.list[0].type", @rov.current_variable_as_expression)

    @rov.execute('a')
    assert_equal("_.list[0]", @rov.current_variable_as_expression)

    @rov.execute('a')
    assert_equal("_.list", @rov.current_variable_as_expression)

    @rov.execute('a')
    assert_equal("_.list", @rov.current_variable_as_expression)
  end

  def test_open_deep_and_home
    assert_equal("_.list", @rov.current_variable_as_expression)

    @rov.execute('d')
    @rov.execute('d')
    @rov.execute('s')
    @rov.execute('d')

    assert_equal("_.list[0].type.markers", @rov.current_variable_as_expression)

    @rov.execute('h')

    assert_equal("_.list", @rov.current_variable_as_expression)
  end

  def test_stops_opening_at_leaf
    assert_equal("_.list", @rov.current_variable_as_expression)

    32.times { @rov.execute('d') }

    assert_equal("_.list[0].rand", @rov.current_variable_as_expression)
  end

  def test_open_and_close
    assert_equal("_.list", @rov.current_variable_as_expression)

    @rov.execute('d')
    @rov.execute('d')
    @rov.execute('s')

    assert_equal("_.list[0].type", @rov.current_variable_as_expression)

    @rov.execute('a')
    @rov.execute('e')

    assert_equal("_.list[0]", @rov.current_variable_as_expression)
  end

  def test_parallel_open
    assert_equal("_.list", @rov.current_variable_as_expression)

    @rov.execute('d')
    @rov.execute('d')
    @rov.execute('p')
  end
end
