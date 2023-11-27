module Mobilis
  module OS
    # https://stackoverflow.com/questions/170956/how-can-i-find-which-operating-system-my-ruby-program-is-running-on

    def self.windows?
      (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
    end

    def self.mac?
      (/darwin/ =~ RUBY_PLATFORM) != nil
    end

    def self.unix?
      !OS.windows?
    end

    def self.linux?
      OS.unix? and !OS.mac?
    end

    def self.jruby?
      RUBY_ENGINE == "jruby"
    end
  end
end
