# frozen_string_literal: true

module Mobilis
  module Browser
    # Ruby's IPAddr is pure Ruby except for its dependency on socket's
    # address-family constants and its optional IPSocket.getaddress hook.
    # WASI does not ship the native socket extension. Supply only the API
    # surface IPAddr needs for numeric IPv4/IPv6 manipulation.
    #
    # This MUST NOT be mistaken for networking support: DNS/socket methods
    # explicitly raise. On native Ruby we always use the real socket library.
    module WasiIpAddrCompatibility
      def self.load!
        require "socket"
      rescue LoadError => error
        raise unless %w[socket socket.so].include?(error.path)

        unless defined?(::Socket)
          Object.const_set(:BasicSocket, Class.new) unless defined?(::BasicSocket)
          unless defined?(::IPSocket)
            Object.const_set(:IPSocket, Class.new(::BasicSocket) do
              def self.getaddress(_host)
                raise NotImplementedError, "DNS/network access is unavailable in Ruby WASM"
              end
            end)
          end
          Object.const_set(:Socket, Class.new(::IPSocket))
        end
        ::Socket.const_set(:AF_UNSPEC, 0) unless ::Socket.const_defined?(:AF_UNSPEC)
        ::Socket.const_set(:AF_INET, 2) unless ::Socket.const_defined?(:AF_INET)
        ::Socket.const_set(:AF_INET6, 10) unless ::Socket.const_defined?(:AF_INET6)

        # Tell the Ruby require loader that the unsupported native extension
        # was handled narrowly. All other socket functionality remains absent.
        $LOADED_FEATURES << "socket.rb" unless $LOADED_FEATURES.any? { |feature| feature.end_with?("/socket.rb") || feature == "socket.rb" }
      end
    end
  end
end
