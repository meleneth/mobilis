module Mobilis
  module YAML
    def self.deep_stringify_keys(obj)
      case obj
      when Hash
        # @type var h: Hash[String, Mobilis::data_value]
        h = {}
        obj.each do |k, v|
          h[k.to_s] = deep_stringify_keys(v)
        end
        h
      when Array
        obj.map { |e| deep_stringify_keys(e) }
      else
        obj
      end
    end
  end
end
