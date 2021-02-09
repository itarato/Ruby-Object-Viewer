require_relative 'r_o_v'

class User
  def initialize
    @uservar1 = 1
    @uservar2 = 4.times.to_a
  end
end

class Nothing; end

class Company
  def initialize
    @nothing = Nothing.new
    @users = {
      john: User.new,
    }
    @heads = {
      "foo" => 'bar',
      "bax" => 'xe',
    }
    @empty_hash = {}
    @empty_array = []
    @some_end = { a: User.new, c: Nothing.new }
  end
end

c = Company.new

ROV[c]