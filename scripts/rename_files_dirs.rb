projectName = ARGV[0]
directory = ARGV[1]

base_names = ['baseProject', 'BaseProject']

# For each name
base_names.each do |base_name|
  # Rename any directories 
  Dir.glob("#{directory}/**/*").each do |path|
    if File.directory?(path)
      File.rename(path, path.gsub(base_name, projectName)) #or upcase if you want to convert to uppercase
    end
  end

  # Rename any files
  Dir.glob("#{directory}/**/*").reverse.each do |file|
    if File.file?(file) && file.include?(base_name)
      new_name = file.gsub(base_name, projectName)
      File.rename(file, new_name) 
    end
  end

  # Rename any strings within xml files
  Dir.glob("#{directory}/**/*").reverse.each do |file|
    if File.file?(file) && file[-4..-1].eql?('.xml')
      text = File.read(file)
      if text.include?(base_name)
        new_contents = text.gsub(base_name, projectName)
        File.open(file, "w") {|f| f.write new_contents }
      end
    end
  end
end