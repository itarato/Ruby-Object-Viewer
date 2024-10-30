# frozen_string_literal: true

# TODO:
# - close parent should work on the child too (go to parent and then close)
# - sluggishness on M1 + Rails + pry
# - fuzzy search - jump
# - parallel open (same trail)
# - memory slabs

class ROV
  #
  # Shared things.
  #
  class Util
    class << self
      def red(s); escape(s, 91); end
      def green(s); escape(s, 92); end
      def yellow(s); escape(s, 93); end
      def blue(s); escape(s, 94); end
      def magenta(s); escape(s, 95); end
      def cyan(s); escape(s, 96); end
      def bold(s); escape(s, 1); end
      def dim(s); escape(s, 22); end
      def invert(s); escape(s, 7); end
      def console_lines; %x`tput lines`.to_i; end
      def console_cols; %x`tput cols`.to_i; end

      def visible_truncate(s, lim)
        return s unless s.size > lim # Quick escape to save gsub use.
        return s unless visible_str_len(s) > lim

        vis_count = 0
        full_count = nil
        in_escape = false


        s.chars.each_with_index do |c, idx|
          if in_escape
            in_escape = false if c == 'm'
          else
            if c == "\e"
              in_escape = true
            else
              vis_count += 1

              if vis_count >= lim - 1
                full_count = idx
                break
              end
            end
          end
        end

        s[..full_count] + "\x1B[0m…"
      end

      def visible_str_len(str); str.gsub(/\e\[\d+m/, '').size; end

      def simple_type?(o)
        case o
        when String, Numeric, Symbol, TrueClass, FalseClass, NilClass then true
        else false
        end
      end

      private

      def escape(s, color_code); "\x1B[#{color_code}m#{s}\x1B[0m"; end
    end
  end

  #
  # The descriptor for various types: how should they behave in the viewer.
  #
  class AbstractTypeBehaviour
    def type_of?(obj)
      raise(NotImplementedError)
    end

    def children_names(obj)
      raise(NotImplementedError)
    end

    def child_at(obj, index)
      raise(NotImplementedError)
    end

    def child_var_name(obj, index)
      raise(NotImplementedError)
    end
  end

  class IOTypeBehaviour < AbstractTypeBehaviour
    def type_of?(obj)
      obj.is_a?(IO)
    end

    def children_names(obj)
      obj.instance_variables
    end

    def child_at(obj, index)
      obj.instance_variable_get(obj.instance_variables[index])
    end

    def child_var_name(obj, index)
      ".#{obj.instance_variables[index][1..-1]}"
    end
  end

  class HashTypeBehaviour < AbstractTypeBehaviour
    def type_of?(obj)
      obj.is_a?(Hash)
    end

    def children_names(obj)
      obj.keys
    end

    def child_at(obj, index)
      obj.values[index]
    end

    def child_var_name(obj, index)
      key = obj.keys[index]

      if Util.simple_type?(key)
        "[#{key.inspect.gsub('"', '\'')}]"
      else
        ".values[#{index}]"
      end
    end
  end

  class EnumerableTypeBehaviour < AbstractTypeBehaviour
    def type_of?(obj)
      obj.is_a?(Enumerable)
    end

    def children_names(obj)
      size = obj.respond_to?(:size) ? obj.size : obj.to_a.size
      size.times.to_a
    end

    def child_at(obj, index)
      obj.to_a[index]
    end

    def child_var_name(obj, index)
      "[#{index}]"
    end
  end

  class ActiveRecordModelSchemaTypeBehaviour < AbstractTypeBehaviour
    def type_of?(obj)
      Object.const_defined?("ActiveRecord::ModelSchema") && obj.is_a?(ActiveRecord::ModelSchema)
    end

    def children_names(obj)
      obj.class.columns.map(&:name)
    end

    def child_at(obj, index)
      obj[obj.class.columns[index].name]
    end

    def child_var_name(obj, index)
      ".#{obj.class.columns[index].name}"
    end
  end

  class GenericObjectTypeBehaviour < AbstractTypeBehaviour
    def type_of?(obj)
      true
    end

    def children_names(obj)
      obj.instance_variables
    end

    def child_at(obj, index)
      obj.instance_variable_get(obj.instance_variables[index])
    end

    def child_var_name(obj, index)
      ".#{obj.instance_variables[index][1..-1]}"
    end
  end

  #
  # Represents an object (~level).
  #
  class Ctx
    attr_reader(:parent_ctx)
    attr_reader(:children_ctx)
    attr_reader(:tag)
    attr_reader(:current_level)
    attr_reader(:obj)
    attr_reader(:selection)

    TYPE_BEHAVIOURS = [
      IOTypeBehaviour.new,
      HashTypeBehaviour.new,
      EnumerableTypeBehaviour.new,
      ActiveRecordModelSchemaTypeBehaviour.new,
      GenericObjectTypeBehaviour.new,
    ]

    def initialize(obj, parent_ctx, current_level:)
      @obj = obj
      @parent_ctx = parent_ctx
      @selection = children_size > 0 ? 0 : nil
      @children_ctx = [nil] * children_size
      @tag = obj.class.name
      @current_level = current_level
    end

    def select_next
      return unless children_size > 0
      self.selection = (selection + 1) % children_size
    end

    def select_prev
      return unless children_size > 0
      self.selection = (selection - 1) % children_size
    end

    def select_first
      self.selection = 0
    end

    def select_last
      self.selection = children_size - 1
    end

    def at_last_child?
      selection == children_size - 1
    end

    def at_first_child?
      selection == 0
    end

    def children_size
      @children_size ||= children_names.size
    end

    def has_children?
      children_size > 0
    end

    def children_names
      return @children_names if defined?(@children_names)

      TYPE_BEHAVIOURS.each do |type_behaviour|
        if type_behaviour.type_of?(obj)
          return @children_names = type_behaviour.children_names(obj)
        end
      end

      raise("No type behaviour has found")
    end

    #
    # Actual object children (raw object).
    #
    def child_at(index)
      TYPE_BEHAVIOURS.each do |type_behaviour|
        if type_behaviour.type_of?(obj)
          return type_behaviour.child_at(obj, index)
        end
      end

      raise("No type behaviour has found")
    end

    def active_child
      return if selection.nil?

      raise("Selection must be positive") unless selection >= 0
      raise("Selection is out of bounds") unless selection < children_size

      child_at(selection)
    end

    def active_child_var_name
      TYPE_BEHAVIOURS.each do |type_behaviour|
        if type_behaviour.type_of?(obj)
          return type_behaviour.child_var_name(obj, selection)
        end
      end

      raise("No type behaviour has found")
    end

    def active_child_open?
      !children_ctx[selection].nil?
    end

    def child_openable?(index)
      elem = child_at(index)

      TYPE_BEHAVIOURS.each do |type_behaviour|
        if type_behaviour.type_of?(elem)
          return type_behaviour.children_names(elem).size > 0
        end
      end

      raise("No type behaviour has found")
    end

    def active_child_openable?
      child_openable?(selection)
    end

    def open_active_child
      raise("Child is not openable") unless active_child_openable?
      children_ctx[selection] ||= Ctx.new(active_child, self, current_level: current_level + 1)
    end

    def open_nth_child(idx)
      raise("Child is not openable") unless child_openable?(idx)
      children_ctx[idx] ||= Ctx.new(child_at(idx), self, current_level: current_level + 1)
    end

    def open_children
      children_size.times do |i|
        next unless children_ctx[i].nil?
        next unless child_openable?(i)

        children_ctx[i] = Ctx.new(child_at(i), self, current_level: current_level + 1)
      end
    end

    # TODO: Lets not lose the object, lets have a prop for closed.
    def close_active_child
      children_ctx[selection] = nil
    end

    def close_children
      children_size.times { |i| children_ctx[i] = nil }
    end

    #
    # @return [String, Boolean] = [Output, Is-cursor-line?]
    #
    def pretty_print(active_ctx, indent = '  ')
      out = []

      children_names.zip(children_ctx).each_with_index do |(elem_name, child_ctx), index|
        value_suffix = child_openable?(index) ? '' : " = #{Util.cyan(child_at(index).to_s)}"
        tag_suffix = " (#{Util.magenta(child_at(index).class.name)})#{value_suffix}"

        is_active_line = self == active_ctx && selection == index
        active_pos_marker = is_active_line ? '>' : ' '
        nesting_symbol = index == children_size - 1 ? '└' : '├'
        tree_more_symbol = child_openable?(index) ? '+ ': ' '

        line = <<~LINE.lines(chomp: true).join
          #{indent}
          #{Util.bold(Util.yellow(active_pos_marker))}
          #{nesting_symbol}─
          #{tree_more_symbol}
          #{is_active_line ? Util.invert(Util.blue(elem_name)) : Util.blue(elem_name)}
          #{tag_suffix}
        LINE

        out << [line, is_active_line]

        if child_ctx
          tree_guide = index == children_size - 1 ? ' ' : '¦'
          out += child_ctx.pretty_print(active_ctx, indent + " #{tree_guide}")
        end
      end

      out
    end

    def is_list
      @obj.is_a?(Enumerable)
    end

    private

    def children_ctx=
      raise
    end

    def parent_ctx=
      raise
    end

    def obj=
      raise
    end

    attr_writer(:selection)
  end

  class << self
    def [](obj)
      ROV.new(obj).loop
    end
  end

  def initialize(obj)
    @root_ctx = @active_ctx = Ctx.new(obj, nil, current_level: 0)
    @is_running = true
    @terminal_width = Util.console_cols
    @variable_name = get_input_presentation
  end

  def loop
    return unless root_ctx.has_children?

    while @is_running
      print_root
      execute(read_char)
    end

    current_variable_as_expression
  end

  def execute(input)
    case input
    when 'q' then stop_loop
    when 'w' then step_up
    when 's' then step_down
    when 'a' then step_parent
    when 'd' then step_child
    when 'h' then step_home
    when 'e' then close_active_child
    when '0'..'9' then open_tree_level(input.to_i)
    when 'i' then idbg_ext_log
    when 'p' then open_parallel_children
    end
  end

  def current_variable_as_expression
    @variable_name + active_var_path
  end

  private

  attr_reader :root_ctx
  attr_accessor :active_ctx

  def root_ctx=
    raise
  end

  #
  # Quit.
  #
  def stop_loop
    @is_running = false
  end

  #
  # Set current CTX to the parent.
  #
  def step_parent
    self.active_ctx = active_ctx.parent_ctx unless active_ctx.parent_ctx.nil?
  end

  #
  # Set current CTX to active child.
  #
  def step_child
    self.active_ctx = active_ctx.open_active_child if active_ctx.active_child_openable?
  end

  #
  # Set current CTX to root.
  #
  def step_home
    self.active_ctx = root_ctx
    active_ctx.select_first
  end

  #
  # Clost current CTX active child.
  #
  def close_active_child
    active_ctx.close_active_child
  end

  #
  # Set active CTX to previous child or previous opened subtree last leaf.
  #
  def step_up
    if active_ctx.at_first_child?
      if active_ctx.parent_ctx
        self.active_ctx = active_ctx.parent_ctx
      else
        active_ctx.select_last

        while active_ctx.active_child_open?
          self.active_ctx = active_ctx.open_active_child
          active_ctx.select_last
        end
      end
      return
    end

    active_ctx.select_prev

    while active_ctx.active_child_open?
      self.active_ctx = active_ctx.open_active_child
      active_ctx.select_last
    end
  end

  #
  # Set active CTX to next child or next opened subtree first node.
  #
  def step_down
    if active_ctx.active_child_open?
      self.active_ctx = active_ctx.open_active_child
      active_ctx.select_first
      return
    end

    unless active_ctx.at_last_child?
      active_ctx.select_next
      return
    end

    while active_ctx.at_last_child? && active_ctx.parent_ctx
      self.active_ctx = active_ctx.parent_ctx
    end

    active_ctx.select_next
  end

  #
  # Open all nodes on level N.
  #
  def open_tree_level(n)
    while n < active_ctx.current_level
      self.active_ctx = active_ctx.parent_ctx
    end

    open_tree_level_until(root_ctx, n)
  end

  def open_tree_level_until(ctx, n)
    if n == 0
      ctx.close_children
      return
    end

    ctx.open_children
    ctx.children_ctx.each do |child_ctx|
      next unless child_ctx

      open_tree_level_until(child_ctx, n - 1)
    end
  end

  def idbg_ext_log
    return unless Object.const_defined?("IDbg")
    IDbg.log("ROV", current_variable_as_expression, active_ctx.active_child)
  end

  def open_parallel_children
    # Find first enumerable parent.
    enumerable_parent_ctx = active_ctx
    trail = []

    while enumerable_parent_ctx
      break if enumerable_parent_ctx.is_list

      trail.unshift(enumerable_parent_ctx.selection)

      enumerable_parent_ctx = enumerable_parent_ctx.parent_ctx
    end
    return unless enumerable_parent_ctx

    # Set expected type.
    expected_class = enumerable_parent_ctx.active_child.class

    # Check if all child is the same.
    is_uniform = enumerable_parent_ctx.obj.to_a.all? { |e| e.is_a?(expected_class) }

    return unless is_uniform

    enumerable_parent_ctx.children_size.times do |i|
      next unless enumerable_parent_ctx.child_openable?(i)

      trail_ctx = enumerable_parent_ctx.open_nth_child(i)

      # trail.shift # First item is the current iteration.
      trail.each do |child_idx|
        break unless trail_ctx.child_openable?(child_idx)

        trail_ctx = trail_ctx.open_nth_child(child_idx)
      end
    end
  end

  def active_var_path
    current_ctx = active_ctx
    path = []
    while current_ctx
      path.unshift(current_ctx.active_child_var_name)
      current_ctx = current_ctx.parent_ctx
    end

    path.join
  end

  def print_root
    clear_terminal

    lines = [[Util.magenta(root_ctx.tag) + ":", false]]
    lines += root_ctx.pretty_print(active_ctx)
    active_line_index = lines.index { |_, is_active| is_active }

    puts (lines[presentable_line_range(active_line_index, lines.size)].map do |line, _|
      Util.visible_truncate(line, @terminal_width)
    end.join("\n"))
    puts "\n📋 #{@variable_name}#{Util.green(active_var_path)}"
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
    system('stty', 'raw', '-echo')
    char = STDIN.getc
    system('stty', '-raw', 'echo')
    char
  end

  def get_input_presentation
    rx = /ROV\[(?<varname>.+)\]$/

    if Object.const_defined?("Pry")
      last_pry_call = Pry.history.to_a.last
      return rx.match(last_pry_call.rstrip)["varname"]
    elsif Object.const_defined?("IRB")
      IRB.CurrentContext.io.save_history
      last_irb_call = IO.readlines(File.expand_path(IRB.rc_file("_history"))).last
      return rx.match(last_irb_call.rstrip)["varname"]
    end

    "_"
  rescue
    "-"
  end
end
