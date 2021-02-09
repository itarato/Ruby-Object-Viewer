class ROV
  class Util
    class << self
      def escape(s, color_code)
        "\e[#{color_code}m#{s}\e[0m"
      end

      def red(s)
        escape(s, 91)
      end

      def green(s)
        escape(s, 92)
      end

      def yellow(s)
        escape(s, 93)
      end

      def blue(s)
        escape(s, 94)
      end

      def magenta(s)
        escape(s, 95)
      end

      def cyan(s)
        escape(s, 96)
      end

      def bold(s)
        escape(s, 1)
      end

      def dim(s)
        escape(s, 22)
      end

      def invert(s)
        escape(s, 7)
      end

      def console_lines
        `tput lines`.to_i
      end

      def console_cols
        `tput cols`.to_i
      end
    end
  end

  class Ctx
    attr_reader :parent_ctx
    attr_reader :children_ctx

    def initialize(obj, parent_ctx)
      @obj = obj
      @parent_ctx = parent_ctx
      @selection = elem_size > 0 ? 0 : nil
      @children_ctx = [nil] * elem_size
    end

    def select_next
      return unless elem_size > 0
      self.selection = (selection + 1) % elem_size
    end

    def select_prev
      return unless elem_size > 0
      self.selection = (selection - 1) % elem_size
    end

    def tag
      obj.class.name
    end
    
    def select_first
      self.selection = 0
    end
    
    def select_last
      self.selection = elem_size - 1
    end

    def at_last_child?
      selection == elem_size - 1
    end

    def at_first_child?
      selection == 0
    end

    def elem_size
      @elem_size ||= case obj
      when Enumerable
        obj.size
      else
        # TODO Maybe this can coexist with enumerable (eg sg that fakes enumarable).
        obj.instance_variables.size
      end
    end

    def elem_names
      case obj
      when Hash
        obj.keys
      when Enumerable
        obj.size.times.to_a
      else
        obj.instance_variables
      end
    end

    def current_level
      level = 0

      ctx = self
      while ctx.parent_ctx
        ctx = ctx.parent_ctx
        level += 1
      end

      level
    end

    def elem_at(index)
      case obj
      when Hash
        obj.values[index]
      when Enumerable
        obj.to_a[index]
      else
        obj.instance_variable_get(obj.instance_variables[index])
      end
    end

    def active_elem
      return if selection.nil?

      raise "Selection must be positive" unless selection >= 0
      raise "Selection is out of bounds" unless selection < elem_size

      elem_at(selection)
    end

    def active_elem_var_name
      case obj
      when Hash
        "[#{obj.keys[selection].inspect.gsub('"', '\'')}]"
      when Enumerable
        "[#{selection}]"
      else
        ".#{obj.instance_variables[selection][1..-1]}"
      end
    end

    def active_child_open?
      !children_ctx[selection].nil?
    end

    def child_openable?(index)
      elem = elem_at(index)
      case elem
      when Enumerable
        elem.to_a.size > 0
      else
        elem.instance_variables.size > 0
      end
    end

    def active_child_openable?
      child_openable?(selection)
    end

    def dig
      raise "Child is not diggable" unless active_child_openable?
      children_ctx[selection] ||= Ctx.new(active_elem, self)
    end

    def dig_all
      elem_size.times do |i|
        next unless children_ctx[i].nil?
        next unless child_openable?(i)

        children_ctx[i] = Ctx.new(elem_at(i), self)
      end
    end

    def undig
      children_ctx[selection] = nil
    end

    def undig_all
      elem_size.times { |i| children_ctx[i] = nil }
    end

    #
    # @return [String, Boolean]
    #
    def pretty_print(active_ctx, indent = '  ')
      out = []

      elem_names.zip(children_ctx).each_with_index do |(elem_name, child_ctx), index|
        value_suffix = child_openable?(index) ? '' : " = #{Util.cyan(elem_at(index).to_s)}"
        tag_suffix = " (#{Util.magenta(elem_at(index).class.name)})#{value_suffix}"

        is_active_line = self == active_ctx && selection == index
        active_pos_marker = is_active_line ? '>' : ' '
        nesting_symbol = index == elem_size - 1 ? '└' : '├'

        tree_more_symbol = child_openable?(index) ? '+ ': ' '

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

    private

    def children_ctx=
      raise
    end

    def parent_ctx=
      raise
    end

    attr_accessor :obj
    attr_accessor :selection
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

      cmd = read_char

      case cmd
      when 'q' then stop_loop
      when 'w' then step_up
      when 's' then step_down
      when 'a' then step_parent
      when 'd' then step_child
      when 'h' then step_home
      when 'e' then close_child
      when '0'..'9' then open_tree_level(cmd.to_i)
      end
    end

    active_var_path
  end

  private

  def stop_loop
    @is_running = false
  end

  def step_parent
    @active_ctx = @active_ctx.parent_ctx unless @active_ctx.parent_ctx.nil?
  end

  def step_child
    @active_ctx = @active_ctx.dig if @active_ctx.active_child_openable?
  end

  def step_home
    @active_ctx = @root_ctx
    @active_ctx.select_first
  end

  def close_child
    @active_ctx.undig
  end

  def step_up
    if @active_ctx.at_first_child?
      if @active_ctx.parent_ctx
        @active_ctx = @active_ctx.parent_ctx
      else
        @active_ctx.select_last

        while @active_ctx.active_child_open?
          @active_ctx = @active_ctx.dig
          @active_ctx.select_last
        end
      end
      return
    end

    @active_ctx.select_prev
    
    while @active_ctx.active_child_open?
      @active_ctx = @active_ctx.dig
      @active_ctx.select_last
    end
  end

  def step_down
    if @active_ctx.active_child_open?
      @active_ctx = @active_ctx.dig
      @active_ctx.select_first
      return
    end

    unless @active_ctx.at_last_child?
      @active_ctx.select_next
      return
    end

    while @active_ctx.at_last_child? && @active_ctx.parent_ctx
      @active_ctx = @active_ctx.parent_ctx
    end

    @active_ctx.select_next
  end

  def open_tree_level(n)
    while n < @active_ctx.current_level
      @active_ctx = @active_ctx.parent_ctx
    end

    open_tree_level_until(@root_ctx, n)
  end

  def open_tree_level_until(ctx, n)
    if n == 0
      ctx.undig_all
      return
    end

    ctx.dig_all
    ctx.children_ctx.each do |child_ctx|
      next unless child_ctx

      open_tree_level_until(child_ctx, n - 1)
    end
  end

  def active_var_path
    current_ctx = @active_ctx
    path = []
    until current_ctx.nil?
      path.unshift(current_ctx.active_elem_var_name)
      current_ctx = current_ctx.parent_ctx
    end

    path.join
  end

  def print_root
    clear_terminal

    lines = [[Util.magenta(@root_ctx.tag) + ":", false]]
    lines += @root_ctx.pretty_print(@active_ctx)
    active_line_index = lines.index { |_, is_active| is_active }

    puts lines[presentable_line_range(active_line_index, lines.size)].map { |the_string, _| the_string }.join("\n")
    puts "\n📋 _#{Util.green(active_var_path)}"
  end

  def presentable_line_range(mid_index, len)
    padding = (Util.console_lines - 4) / 2

    if mid_index <= padding
      from = 0
      to = [padding * 2 + 1, len - 1].min
    elsif mid_index + padding >= len
      to = len - 1
      from = [0, to - 1 - 2 * padding].max
    else
      from = [0, mid_index - padding - 1].max
      to = [mid_index + padding, len].min
    end

    from..to
  end

  def clear_terminal
    print `clear`
  end

  def read_char
    system('stty raw -echo')
    char = STDIN.getc
    system('stty -raw echo')
    char
  end
end
