require_relative 'rov'

class User
  def initialize
    @uservar1 = 1
    @uservar2 = [1, 2, 3]
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
  end
end

c = Company.new

ROV[c]