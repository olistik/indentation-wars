files = Dir["files/*.js"]
space_indented_count = files.select do |file|
  File.read(file).split("\n").any? do |line|
    line.match /^  .*/
  end
end.count

puts "Among the #{files.count} most popular Javascript projects in Github, #{space_indented_count} uses space indendation"
