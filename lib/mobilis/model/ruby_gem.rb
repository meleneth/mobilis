# frozen_string_literal: true

module Mobilis
  module Model
    class RubyGem
      attr_reader :name, :git, :branch, :group, :path, :require_name

      def initialize(name, git: nil, branch: nil, group: nil, path: nil, require_name: nil)
        @name = name
        @git = git
        @branch = branch
        @group = group
        @path = path
        @require_name = require_name
      end

      def bundle_add_args
        args = [name]
        args.concat(["--git", git]) if git
        args.concat(["--branch", branch]) if branch
        args.concat(["--group", group]) if group
        args.concat(["--path", path]) if path
        args.concat(["--require", require_name]) if require_name
        args
      end

      def gemfile_line
        options = []
        options << %(git: #{git.inspect}) if git
        options << %(branch: #{branch.inspect}) if branch
        options << %(group: #{group.inspect}) if group
        options << %(path: #{path.inspect}) if path
        options << %(require: #{require_name.inspect}) if require_name
        suffix = options.empty? ? "" : ", #{options.join(", ")}"
        %(gem #{name.inspect}#{suffix})
      end

      def to_h
        {
          type: self.class.name,
          name: name,
          git: git,
          branch: branch,
          group: group,
          path: path,
          require_name: require_name
        }.compact
      end

      def self.from_h(hash)
        new(
          hash[:name],
          git: hash[:git],
          branch: hash[:branch],
          group: hash[:group],
          path: hash[:path],
          require_name: hash[:require_name]
        )
      end
    end
  end
end
