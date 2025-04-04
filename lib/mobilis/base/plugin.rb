# frozen_string_literal: true

# Base class for Mobilis plugins. Provides structured hook points for
# interaction at various phases of the realization and emission pipeline.
#
# Subclasses should override only the hooks they need.
module Mobilis
  module Base
    class Plugin
      # Called before any realization occurs.
      # Plugins may inspect or (if explicitly permitted) mutate the system.
      #
      # @param system [Mobilis::System]
      # @param execution_environment [ExecutionEnvironment]
      def before_realization(system, execution_environment)
        # Override in subclass
      end

      # Called for each node during realization.
      # Plugins may augment or wrap realization behavior.
      #
      # @param node [Mobilis::Node]
      # @param realized_env [Mobilis::RealizedEnv]
      def realize_node(node, realized_env)
        # Override in subclass
      end

      # Called after full environment realization.
      # Plugins may inspect or modify the realized environment.
      #
      # @param realized_env [Mobilis::RealizedEnv]
      def after_realization(realized_env)
        # Override in subclass
      end

      # Declares any files this plugin intends to emit.
      # Called before emitters begin writing files.
      #
      # @param realized_env [Mobilis::RealizedEnv]
      # @return [Array<Mobilis::FileSpec>] (optional)
      def planned_files(realized_env)
        []
      end

      # Called before a file is emitted.
      # Plugin may modify or veto the file.
      #
      # @param file_spec [Mobilis::FileSpec]
      def before_emit(file_spec)
        # Override in subclass
      end

      # Called after a file is emitted.
      #
      # @param file_spec [Mobilis::FileSpec]
      def after_emit(file_spec)
        # Override in subclass
      end

      # Optional: declare explicit startup dependencies.
      # E.g., Rails should wait for PostgreSQL.
      #
      # @param realized_node [Mobilis::Base::RealizedNode]
      # @return [Array<Mobilis::Base::RealizedNode>] (optional)
      def wait_for_dependencies(realized_node)
        []
      end

      # Optional: inject models or code into a Rails service.
      #
      # @param rails_node [Mobilis::RealizedNode::Rails]
      def inject_rails_models(rails_node)
        # Override in subclass
      end

      # Optional: declare extra data volume paths needed by a service.
      #
      # @param realized_node [Mobilis::Base::RealizedNode]
      # @return [Array<String>] (absolute or relative paths)
      def declare_data_paths(realized_node)
        []
      end
    end
  end
end
