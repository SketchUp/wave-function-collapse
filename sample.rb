require 'json'

def weighted_sample(enumerable, rnd)
  sum_weight = enumerable.sum(&:weight)
  value = rnd.rand(sum_weight)
  enumerable.find { |n|
    value -= n.weight
    value < 0
  }
end

Item = Struct.new(:value, :weight)
items = [
  Item.new('hello', 1),
  Item.new('world', 5),
  Item.new('universe', 2),
]

iterations = ARGV[0].to_i
random = Random.new
output = iterations.times.map { |i|
  weighted_sample(items, random)
}

stats = output.tally
puts JSON.pretty_generate(stats)

sum_weights = items.sum(&:weight)
items.each { |item|
  base_ratio = item.weight.to_f / sum_weights.to_f
  ratio = stats[item].to_f / iterations.to_f
  puts "#{item.value.rjust(10)} - Ratio: %.6f vs %.6f" % [base_ratio, ratio]
}
