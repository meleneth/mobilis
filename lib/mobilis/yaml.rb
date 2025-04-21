module Mobilis
  module YAML
    def self.deep_stringify_keys(obj)
      case obj
      when Hash
        obj.each_with_object({}) do |(k, v), h|
          h[k.to_s] = deep_stringify_keys(v)
        end
      when Array
        obj.map { |e| deep_stringify_keys(e) }
      else
        obj
      end
    end
  end
end
