require 'snifter_globals'

class SnifterStats
  def self.show
    $snifters.each do |snifter|
      puts snifter.id, '--------------------------'
      snifter.show_stats
      puts ''
    end
  end
end
