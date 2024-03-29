Ruby Object Viewer (rov)
------------------------

![Example](misc/example.png)

If you ever pry debugged large objects in Ruby on a terminal and got frustrated how hard to inspect large objects - other than printing them out and scrabble the details from pages of inspect-output - this might be for you.

This one file tool allows traversing objects bit by bit like a tree with a nice TUI and even helps showing a path of trails.

## Usage

Via gems:

```bash
gem install r_o_v
```

and in your Ruby source:

```ruby
require("r_o_v")
```

As single file:

It is one file so you can copy into a large project that doesn't allow live-loading gems (but at least you can gitignore this).
Tip: use `bash` instead of bloated shells (eg `zsh`) to make it faster (input request from the OS is quicker when a shell has a small footprint).

Once you loaded the file:

```bash
pry#> ROV[complex_object]
```

Keys:

```
         up ┌─close subtree
   quit   │ │     ┌─IDbg.log
    │     ▼ ▼     ▼
    │  ┌─┬─┬─┬   ┌─┬ ┬─┐
    └─►│q│w│e│   │i│ │p│◄───Open parallel children
       ├─┼─┼─┼ ┬─┼─┴ ┴─┘
   ┌──►│a│s│d│ │h│◄───home
   │   └─┴─┴─┴ ┴─┘
go parent ▲ ▲
          │ └──open/go subtree
          └─down

┌─┬─┬────────┬─┬─┐
│1│2│...     │9│0│◄──open N levels
└─┴─┴────────┴─┴─┘
```