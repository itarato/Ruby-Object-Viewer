require_relative 'r_o_v'
require 'set'

class Organism
  class BetaMarker; end
  class AlphaMarker; end

  class CellState
    def initialize
      @states = %w(replication chrom-segregation cytokinesis)
      @active_state_idx = 3
    end
  end

  class CellType
    def initialize
      @markers = { BetaMarker.new => [1, 2], AlphaMarker.new => [2, 3] }
      @comps = Set.new(['globular', 'glycolipid', 'carbohydrate'])
    end
  end

  class Cell
    def initialize
      @type = CellType.new
      @proteins = { No2: 12, CoBRo: 32, FhZ: 2 }
      @state = CellState.new
      @surrounding = [100.times.to_a]
    end
  end

  def initialize
    @cells = [
      Cell.new,
      Cell.new
    ]
  end
end

ROV[Organism.new]
