# frozen_string_literal: true

module Mobilis
  module Model
    class RubyGem
      attr_reader :name, :git, :branch, :group, :require_name

      def initialize(name, git: nil, branch: nil, group: nil, require_name: nil)
        @name = name
        @git = git
        @branch = branch
        @group = group
        @require_name = require_name
      end

      def bundle_add_args
        args = [name]
        args.concat(["--git", git]) if git
        args.concat(["--branch", branch]) if branch
        args.concat(["--group", group]) if group
        args.concat(["--require", require_name]) if require_name
        args
      end

      def to_h
        {
          type: self.class.name,
          name: name,
          git: git,
          branch: branch,
          group: group,
          require_name: require_name
        }.compact
      end

      def self.from_h(hash)
        new(
          hash[:name],
          git: hash[:git],
          branch: hash[:branch],
          group: hash[:group],
          require_name: hash[:require_name]
        )
      end
    end
  end
end
