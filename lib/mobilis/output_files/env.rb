module Mobilis
  module OutputFiles
    class Env < Mobilis::OutputFile
      attr_reader :metaproject, :environment

      def initialize(environment, metaproject, allocate_port_no_proc)
        super("#{environment}.env")
        @metaproject = metaproject
        @environment = environment
        @allocate_port_no_proc = allocate_port_no_proc
      end

      def runasuser
        "#{Process.uid}:#{Process.gid}"
      end

      def render
        env_vars = SymbolKeyHash.new
        metaproject.projects.each do |project|
          env_vars.merge! project.global_env_vars(environment)
        end
        env_vars["ENVIRONMENT"] = environment
        env_vars["RUNASUSER"] = runasuser
        env_lines = [] # : Array[String]
        env_vars.keys.sort.each do |key|
          value = env_vars[key]
          value = @allocate_port_no_proc.call if value == "AUTO_EXTERNAL_PORT"
          actual_key = key.to_s.tr("-", "_")
          env_lines << "#{actual_key}=#{value}"
        end
        env_lines.push("").join("\n")
      end
    end
  end
end
