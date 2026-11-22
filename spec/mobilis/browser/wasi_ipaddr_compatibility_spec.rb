# frozen_string_literal: true

require "spec_helper"
require "open3"
require "rbconfig"

RSpec.describe Mobilis::Browser::WasiIpAddrCompatibility do
  it "leaves the native Socket implementation untouched" do
    require "socket"
    socket_class = Socket

    described_class.load!

    expect(Socket).to equal(socket_class)
    expect(IPAddr.new("127.0.0.1").to_s).to eq("127.0.0.1")
    expect(IPAddr.new("::1").to_s).to eq("::1")
  end

  it "supports numeric IPAddr without silently providing networking when socket is absent" do
    program = <<~RUBY
      module Kernel
        alias original_require require
        def require(feature)
          if feature == "socket"
            error = LoadError.new("cannot load such file -- socket")
            error.define_singleton_method(:path) { "socket" }
            raise error
          end
          original_require(feature)
        end
      end

      require "mobilis/browser/wasi_ipaddr_compatibility"
      Mobilis::Browser::WasiIpAddrCompatibility.load!
      require "ipaddr"
      abort "IPv4 failed" unless IPAddr.new("127.0.0.1").to_s == "127.0.0.1"
      abort "IPv6 failed" unless IPAddr.new("::1").to_s == "::1"
      begin
        IPSocket.getaddress("example.com")
        abort "network operation unexpectedly succeeded"
      rescue NotImplementedError => error
        abort "incorrect networking failure" unless error.message.include?("unavailable")
      end
    RUBY

    lib = File.expand_path("../../../lib", __dir__)
    output, status = Open3.capture2e(RbConfig.ruby, "-I", lib, "-e", program)
    expect(status.success?).to eq(true), output
  end
end
