# frozen_string_literal: true

# ruby.wasm 2.10.1 builds third-party static extensions before its final Ruby
# library. mkmf's link probes nevertheless use -lruby-static. Nokogiri's
# iconv probes therefore fail even when WASI libiconv is installed.
#
# Compile the *real* cross-target Ruby archive before probing extensions,
# and make it available at the -L. searched by mkmf. Do not create an empty
# stand-in archive or suppress mkmf checks. The actual final Ruby link remains
# owned by ruby.wasm.
require "ruby_wasm"
require "fileutils"
require "open3"

module MobilisEarlyRubyArchive
  class NokogiriExecutor
    def initialize(delegate)
      @delegate = delegate
    end

    def system(*args, **kwargs)
      if args.join(" ").include?("ext/nokogiri/extconf.rb")
        # ruby.wasm's legacy extconf runner sets $extout and $static, but
        # omits $extmk. Ruby mkmf uses BOTH $extmk and $extout when routing
        # install directories to the cross-Ruby extension build tree.
        # Without $extmk, Nokogiri's generated Makefile tries /usr/local.
        static_arg = '$static = true; trace_var(:$static) {|v| $static = true }'
        index = args.index(static_arg)
        raise "ruby.wasm extconf invocation changed: missing static setup" unless index
        args = args.dup
        args[index] = '$extmk = true; ' + static_arg

        kwargs = kwargs.dup
        kwargs[:env] = (kwargs[:env] || {}).merge(
          "RUBYOPT" => "-r#{File.expand_path("nokogiri_wasi_patch", __dir__)}"
        )
      end
      @delegate.system(*args, **kwargs)
    end

    def method_missing(method, *args, **kwargs, &block)
      @delegate.public_send(method, *args, **kwargs, &block)
    end

    def respond_to_missing?(method, include_private = false)
      @delegate.respond_to?(method, include_private) || super
    end
  end

  module CoreBeforeGemExtensions
    def build_exts(executor)
      archive = File.join(build_dir, "libruby-static.a")
      unless File.file?(archive) && File.size?(archive)
        executor.system("make", "-C", build_dir, "libruby-static.a")
      end
      unless File.file?(archive) && File.size?(archive)
        raise "ruby.wasm failed to build real cross-target archive: #{archive}"
      end
      super

      # Third-party mkmf checks are complete. Before Ruby's final static link,
      # discard the dummy init members from the original cross-Ruby archive.
      # Ruby's final make supplies the actual ext/extinit.o and enc/encinit.o.
      ar = toolchain.ar
      ranlib = toolchain.ranlib
      members, error, status = Open3.capture3(ar, "t", archive)
      raise "Cannot inspect WASI Ruby archive: #{error}" unless status.success?
      names = members.lines.map(&:strip)
      placeholders = %w[dmyext.o dmyenc.o] & names
      unless placeholders.empty?
        executor.system(ar, "d", archive, *placeholders)
        executor.system(ranlib, archive)
      end
    end
  end

  module LinkNokogiriStaticDependencies
    def build(executor, crossruby, extra_mkargs = [])
      super
      return unless name.include?("nokogiri-")

      # ruby.wasm records only the extension directory's *.a archives.
      # Nokogiri's packed static dependencies live under ports/ instead,
      # so they must be explicitly supplied to the final Ruby link.
      objdir = product_build_dir(crossruby)
      ports = File.join(objdir, "ports")
      required = {
        "exslt" => "libxslt/*/lib/libexslt.a",
        "xslt"  => "libxslt/*/lib/libxslt.a",
        "xml2"  => "libxml2/*/lib/libxml2.a",
        "gumbo" => "libgumbo/*/lib/libgumbo.a"
      }
      archives = required.map do |name, pattern|
        matches = Dir.glob(File.join(ports, "*", pattern))
        unless matches.size == 1 && File.size?(matches.first)
          raise "Expected exactly one WASI #{name} archive under #{ports}: #{matches.inspect}"
        end
        matches.first
      end

      prefix = File.expand_path("../wasi-dependencies", crossruby.build_dir)
      zlib = File.join(
        File.dirname(crossruby.build_dir), "zlib-1.3.1",
        "opt/usr/local/lib/libz.a"
      )
      extras = [
        File.join(prefix, "lib/liblzma.a"),
        zlib,
        File.join(prefix, "lib/libiconv.a")
      ]
      extras.each do |file|
        raise "Missing WASI static dependency: #{file}" unless File.size?(file)
      end

      # Static archives can refer to one another (especially libxslt and
      # libxml2). A linker group resolves those references without depending
      # on a fragile single left-to-right scan.
      list = linklist(crossruby)
      existing = File.readlines(list, chomp: true).reject(&:empty?)
      probe = File.join(objdir, "libruby-static.a")
      if existing.include?(probe) || existing.any? { |entry| File.basename(entry) == "libruby-static.a" }
        raise "Ruby probe archive unexpectedly entered Nokogiri final link list"
      end
      File.write(list, (
        existing + ["-Wl,--start-group"] + archives + extras +
        ["-Wl,--end-group"]
      ).join("\n") + "\n")
    end
  end

  module LinkRealArchiveInMkmfProbes
    def do_legacy_extconf(executor, crossruby)
      archive = File.join(crossruby.build_dir, "libruby-static.a")
      unless File.file?(archive) && File.size?(archive)
        raise "missing cross-target libruby-static.a before extconf: #{archive}"
      end

      objdir = product_build_dir(crossruby)
      FileUtils.mkdir_p(objdir)
      link = File.join(objdir, "libruby-static.a")
      FileUtils.rm_f(link)

      # mkmf probes need the real Ruby symbols, but the early cross-Ruby
      # archive still contains dmyext.o and dmyenc.o. These provide
      # placeholder Init_ext/Init_enc symbols, which collide with Ruby's
      # genuine ext/extinit.o and enc/encinit.o during the final link.
      #
      # Never mutate the upstream archive: install a separate target-native
      # probe copy with ONLY those placeholder objects removed. The final
      # cross-build can then see the real init objects.
      FileUtils.cp(archive, link)
      ar = crossruby.toolchain.ar
      ranlib = crossruby.toolchain.ranlib
      members, error, status = Open3.capture3(ar, "t", link)
      raise "Cannot inspect WASI Ruby archive: #{error}" unless status.success?
      names = members.lines.map(&:strip)
      placeholders = %w[dmyext.o dmyenc.o]
      present = placeholders & names
      unless present.empty?
        executor.system(ar, "d", link, *present)
        executor.system(ranlib, link)
      end
      remaining, error, status = Open3.capture3(ar, "t", link)
      unless status.success? && (placeholders & remaining.lines.map(&:strip)).empty?
        raise "Could not remove Ruby placeholder init objects: #{error}"
      end

      # ruby.wasm clears RUBYOPT for the baseruby extconf invocation.
      # Scope a preload to Nokogiri's extconf only so MiniPortile can apply
      # our WASI libxml2 source patch immediately after extraction.
      begin
        if name.include?("nokogiri-")
          super(MobilisEarlyRubyArchive::NokogiriExecutor.new(executor), crossruby)
        else
          super
        end
      ensure
        # Required only for mkmf's configure-time link probes. Leaving this
        # archive in objdir would cause ruby.wasm's *.a glob to include it in
        # the final extension link list.
        FileUtils.rm_f(link)
      end
    end
  end
end

RubyWasm::CrossRubyProduct.prepend(
  MobilisEarlyRubyArchive::CoreBeforeGemExtensions
)
RubyWasm::CrossRubyExtProduct.prepend(
  MobilisEarlyRubyArchive::LinkRealArchiveInMkmfProbes
)

RubyWasm::CrossRubyExtProduct.prepend(
  MobilisEarlyRubyArchive::LinkNokogiriStaticDependencies
)
