"""
TODOS:
"""

class ROV
  class Util
    class << self
      def color(s, color_code); "\e[#{color_code}m#{s}\e[0m"; end
      def red(s); color(s, 91); end
      def green(s); color(s, 92); end
      def yellow(s); color(s, 93); end
      def blue(s); color(s, 94); end
      def magenta(s); color(s, 95); end
      def cyan(s); color(s, 96); end
      def bold(s); color(s, 1); end
      def dim(s); color(s, 22); end
      def invert(s); color(s, 7); end
      def console_lines; `tput lines`.to_i; end
      def console_cols; `tput cols`.to_i; end
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

    def select_last
      @selection = elem_size - 1
    end

    def at_last_child?
      @selection == elem_size - 1
    end

    def at_first_child?
      @selection == 0
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
        "[#{@obj.keys[@selection].inspect.gsub('"', '\'')}]"
      when Enumerable
        "[#{@selection}]"
      else
        ".#{@obj.instance_variables[@selection][1..-1]}"
      end
    end

    def already_digged?
      !@children_ctx[@selection].nil?
    end

    def can_dig_at?(index)
      elem = elem_at(index)
      case elem
      when Enumerable
        elem.to_a.size > 0
      else
        elem.instance_variables.size > 0
      end
    end

    def can_dig?
      can_dig_at?(@selection)
    end

    def dig
      raise "Child is not diggable" unless can_dig?
      @children_ctx[@selection] ||= Ctx.new(selected_elem, self)
    end

    def undig
      @children_ctx[@selection] = nil
    end

    #
    # @return [String, Boolean]
    #
    def pretty_print(active_ctx, indent = '  ')
      out = []

      elem_names.zip(@children_ctx).each_with_index do |(elem_name, child_ctx), index|
        value_suffix = can_dig_at?(index) ? '' : " = #{Util.cyan(elem_at(index).to_s)}"
        tag_suffix = " (#{Util.magenta(elem_at(index).class.name)})#{value_suffix}"

        is_active_line = self == active_ctx && @selection == index
        active_pos_marker = is_active_line ? '>' : ' '
        nesting_symbol = index == elem_size - 1 ? '└' : '├'

        tree_more_symbol = can_dig_at?(index) ? '+ ': ' '

        out << [<<~LINE.lines(chomp: true).join, is_active_line]
          #{indent}
          #{Util.bold(Util.yellow(active_pos_marker))}
          #{nesting_symbol}─
          #{tree_more_symbol}
          #{is_active_line ? Util.invert(Util.blue(elem_name)) : Util.blue(elem_name)}
          #{tag_suffix}
        LINE

        unless child_ctx.nil?
          tree_guide = index == elem_size - 1 ? ' ' : '¦'
          out += child_ctx.pretty_print(active_ctx, indent + " #{tree_guide}")
        end
      end

      out
    end
  end

  class << self
    def [](obj)
      ROV.new(obj).loop
    end
  end

  def initialize(obj)
    @root_ctx = @active_ctx = Ctx.new(obj, nil)
    @is_running = true
  end

  def loop
    return unless @root_ctx.elem_size > 0

    while @is_running
      print_root

      cmd = read_command

      case cmd
      when 'q'
        @is_running = false
      when 'w'
        step_up
      when 's'
        @active_ctx.select_next
      when 'a'
        @active_ctx = @active_ctx.parent_ctx unless @active_ctx.parent_ctx.nil?
      when 'd'
        @active_ctx = @active_ctx.dig if @active_ctx.can_dig?
      when 'e'
        @active_ctx.undig
      else
        puts @obj
      end
    end

    active_path
  end

  private

  def step_up
    if @active_ctx.at_first_child?
      if @active_ctx.parent_ctx
        @active_ctx = @active_ctx.parent_ctx
      end
      return
    end

    @active_ctx.select_prev
    
    while @active_ctx.already_digged?
      @active_ctx = @active_ctx.dig
      @active_ctx.select_last
    end
  end

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

    lines = []

    lines << [Util.magenta(@root_ctx.tag), false]
    lines += @root_ctx.pretty_print(@active_ctx)

    active_line_index = lines.index { |_, is_active| is_active }

    padding = (Util.console_lines - 4) / 2

    if active_line_index <= padding
      from = 0
      to = [padding * 2 + 1, lines.size - 1].min
    elsif active_line_index + padding >= lines.size
      to = lines.size - 1
      from = [0, to - 1 - 2 * padding].max
    else
      from = [0, active_line_index - padding - 1].max
      to = [active_line_index + padding, lines.size].min
    end

    puts lines[from..to].map { |the_string, _| the_string }.join("\n")

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
