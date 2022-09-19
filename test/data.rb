require('set')

class Organism
  class BetaMarker; end
  class AlphaMarker; end
  module Foldable; end

  class CellState
    def initialize
      @states = %w(replication chrom-segregation cytokinesis)
      @active_state_idx = 3
      @self_type = CellState
      @self_iface = Foldable
    end
  end

  class CellType
    def initialize
      @markers = { BetaMarker.new => [1, 2], AlphaMarker.new => [2, 3], Foldable => nil }
      @comps = Set.new(['globular', 'glycolipid', 'carbohydrate'])
    end
  end

  class Cell
    def initialize
      @rand = rand % 100
      @type = CellType.new
      @proteins = { No2: 12, CoBRo: 32, FhZ: 2 }
      @state = CellState.new
      @long_abstract = "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum."
      @surrounding = [100.times.to_a]
    end
  end

  def initialize
    @list = 4.times.map { Cell.new }
    @cells = [
      Cell.new,
      Cell.new,
      {
        apostosis: [1, nil, {}],
      }
    ]
  end
end

organism = Organism.new
