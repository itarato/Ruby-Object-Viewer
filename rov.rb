class ROV
  class Util
    class << self
      def color(s, color_code); "\e[#{color_code}m#{s}\e[0m"; end
      def red(s); color(s, 91); end
      def green(s); color(s, 92); end
      def yellow(s); color(s, 93); end
      def blue(s); color(s, 94); end
      def magenta(s); color(s, 95); end
      def bold(s); color(s, 1); end
      def dim(s); color(s, 22); end
    end
  end

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

    def selected_elem_copyable_name
      case @obj
      when Hash
        "[#{@obj.keys[@selection].inspect}]"
      when Enumerable
        "[#{@selection}]"
      else
        ".#{@obj.instance_variables[@selection][1..-1]}"
      end
    end

    def can_dig_at?(index)
      case elem_at(index)
      when Symbol, String, Numeric, TrueClass, FalseClass, NilClass
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

    def pretty_print(active_ctx, indent = '  ')
      elem_names.zip(@children_ctx).each_with_index do |(elem_name, child_ctx), index|
        value_suffix = can_dig_at?(index) ? '' : " = #{elem_at(index).to_s}"
        tag_suffix = " (#{elem_at(index).class.name})#{value_suffix}"

        active_pos_marker = (self == active_ctx && @selection == index) ? '>' : ' '
        nesting_symbol = index == elem_size - 1 ? '└' : '├'

        puts <<~LINE.lines(chomp: true).join
          #{indent}
          #{Util.bold(Util.yellow(active_pos_marker))}
          #{nesting_symbol} 
          #{Util.blue(elem_name)}
          #{Util.magenta(tag_suffix)}
        LINE

        unless child_ctx.nil?
          tree_guide = index == elem_size - 1 ? ' ' : Util.dim(':')
          child_ctx.pretty_print(active_ctx, indent + " #{tree_guide}")
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

    active_path
  end

  private

  def active_path
    current_ctx = @active_ctx
    path = []
    until current_ctx.nil?
      path.unshift(current_ctx.selected_elem_copyable_name)
      current_ctx = current_ctx.parent_ctx
    end

    path.join
  end

  def print_root
    print `clear`

    puts Util.magenta(@root_ctx.tag)
    @root_ctx.pretty_print(@active_ctx)

    puts ''
    puts "Copy[ _#{Util.green(active_path)} ]"
  end

  def read_command
    system('stty raw -echo') #=> Raw mode, no echo
    char = STDIN.getc
    system('stty -raw echo') #=> Reset terminal mode
    char
  end
end

def rov(obj); ROV.new(obj).loop; end
