class ROV
  class Ctx
    attr_reader :parent_ctx

    def initialize(obj, parent_ctx)
      @obj = obj
      @parent_ctx = parent_ctx
      @selection = elem_size > 0 ? 0 : nil
      @children_ctx = [nil] * elem_size
    end

    def tag
      @obj.class.name
    end

    def select_next
      return unless elem_size > 0
      @selection = (@selection + 1) % elem_size
    end

    def select_prev
      return unless elem_size > 0
      @selection = (@selection - 1) % elem_size
    end

    def elem_size
      @elem_size ||= case @obj
      when Enumerable
        @obj.size
      else
        # TODO Maybe this can coexist with enumerable (eg sg that fakes enumarable).
        @obj.instance_variables.size
      end
    end

    def elem_names
      case @obj
      when Hash
        @obj.keys
      when Enumerable
        @obj.size.times.to_a
      else
        @obj.instance_variables
      end
    end

    def elem_at(index)
      case @obj
      when Hash
        @obj.values[index]
      when Enumerable
        @obj.to_a[index]
      else
        @obj.instance_variable_get(@obj.instance_variables[index])
      end
    end

    def selected_elem
      return if @selection.nil?

      raise "Selection must be positive" unless @selection >= 0
      raise "Selection is out of bounds" unless @selection < elem_size

      elem_at(@selection)
    end

    def can_dig_at?(index)
      case elem_at(index)
      when String, Numeric, TrueClass, FalseClass, NilClass
        false
      else
        true
      end
    end

    def can_dig?
      can_dig_at?(@selection)
    end

    def dig
      raise "Child is not diggable" unless can_dig?
      @children_ctx[@selection] ||= Ctx.new(selected_elem, self)
    end

    def pretty_print(active_ctx, indent_size = 0)
      indent = ' ' * indent_size

      puts "#{indent} #{tag}"
      elem_names.zip(@children_ctx).each_with_index do |(elem_name, child_ctx), index|
        active_pos_marker = (self == active_ctx && @selection == index) ? '>' : ' '
        tag_suffix = if child_ctx.nil?
          value_suffix = can_dig_at?(index) ? '' : " = #{elem_at(index).to_s}"
          " (#{elem_at(index).class.name})#{value_suffix}"
        else
          ''
        end

        puts "#{indent}#{active_pos_marker}- #{elem_name}#{tag_suffix}"

        unless child_ctx.nil?
          child_ctx.pretty_print(active_ctx, indent_size + 2)
        end
      end
    end
  end

  def initialize(obj)
    @root_ctx = @active_ctx = Ctx.new(obj, nil)
    @is_running = true
  end

  def loop
    while @is_running
      print_root

      cmd = read_command

      case cmd
      when 'q'
        @is_running = false
      when 'w'
        @active_ctx.select_prev
      when 's'
        @active_ctx.select_next
      when 'a'
        @active_ctx = @active_ctx.parent_ctx unless @active_ctx.parent_ctx.nil?
      when 'd'
        @active_ctx = @active_ctx.dig if @active_ctx.can_dig?
      else
        puts @obj
      end
    end
  end

  private

  def print_root
    print `clear`
    @root_ctx.pretty_print(@active_ctx)
  end

  def read_command
    system('stty raw -echo') #=> Raw mode, no echo
    char = STDIN.getc
    system('stty -raw echo') #=> Reset terminal mode
    char
  end
end

def rov(obj); ROV.new(obj).loop; end

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
  end
end

c = Company.new

# rov(c)
