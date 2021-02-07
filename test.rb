require_relative 'rov'

class User
  def initialize
    @uservar1 = 1
    @uservar2 = [1, 2, 3]
  end
end

class Company
  def initialize
    @users = {
      john: User.new,
    }
    @heads = {
      "foo" => 'bar',
      "bax" => 'xe',
    }
  end
end

c = Company.new

ROV[c]