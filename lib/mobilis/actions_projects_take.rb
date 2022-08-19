# frozen_string_literal: true

module Mobilis
module ActionsProjectsTake


def append_line filename, line
  lines = IO.readlines filename
  lines << line
  write_file filename do |f|
    f.write(lines.join("\n"))
  end
end

def run_command command
  # fixme
  #Mobilis.logger.info "$ #{command.join " "}"
  puts "-> Running --> #{command}"
  system command
  if $? then
    puts "-> Error running command!"
    exit(1)
  end
end

def oblivious_run_command command
  # fixme
  #Mobilis.logger.info "$ #{command.join " "}"
  puts "-> Running --> #{command}"
  system command
end

def run_docker cmd
  oblivious_run_command "docker #{cmd}"
end

def set_second_line filename, line
  lines = IO.readlines filename
  lines.reverse!
  first_line = lines.pop
  lines << line
  lines << first_line
  lines.reverse!
  write_file filename do |f|
    f.write(lines.join("\n"))
  end
end

def set_file_contents filename, contents
  write_file filename do |f|
    f.write contents
  end
end

def write_file filename, &block
  puts " -> Writing --> #{ filename }"
  File.open(filename, "wb", &block)
end


end
end
