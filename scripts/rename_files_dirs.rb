projectName = ARGV[0]
directory = ARGV[1]

Dir.glob("#{directory}/**/*").reverse.each do |file|
  if File.directory?(file)
    File.rename(file, file.gsub('baseProject', projectName)) #or upcase if you want to convert to uppercase
  end
end

Dir.glob("#{directory}/**/*").reverse.each do |file|
  if File.file?(file) && file.include?('baseProject')
    File.rename(file, file.gsub('baseProject', projectName)) #or upcase if you want to convert to uppercase
  end
end