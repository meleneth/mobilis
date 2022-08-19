module Mobilis
module OS
# https://stackoverflow.com/questions/170956/how-can-i-find-which-operating-system-my-ruby-program-is-running-on

def OS.windows?
  (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
end

def OS.mac?
 (/darwin/ =~ RUBY_PLATFORM) != nil
end

def OS.unix?
  !OS.windows?
end

def OS.linux?
  OS.unix? and not OS.mac?
end

def OS.jruby?
  RUBY_ENGINE == 'jruby'
end

end
end
