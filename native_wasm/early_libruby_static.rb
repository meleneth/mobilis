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
require "shellwords"

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
      # Nokogiri's extconf explicitly embeds its bundled static archives in
      # the generated Makefile LIBS. The library ports are NOT necessarily
      # under objdir: cached libxml2/libxslt archives live under the gem's
      # PACKAGE_ROOT_DIR/ports. Read the generated paths rather than guessing
      # their locations or host/target directory names.
      makefile = File.join(objdir, "Makefile")
      raise "Nokogiri Makefile missing: #{makefile}" unless File.file?(makefile)
      libs_line = File.readlines(makefile).find { |line| line.start_with?("LIBS = ") }
      raise "Nokogiri Makefile missing LIBS declaration" unless libs_line
      static_archives = Shellwords.split(libs_line.delete_prefix("LIBS = ").strip)
        .select { |token| token.end_with?(".a") && token.start_with?("/") }
        .uniq
      required = %w[libexslt.a libxslt.a libxml2.a libgumbo.a]
      archives = required.map do |basename|
        matches = static_archives.select { |archive| File.basename(archive) == basename }
        unless matches.size == 1 && File.size?(matches.first)
          raise "Nokogiri LIBS must identify one built #{basename}: #{matches.inspect}"
        end
        matches.first
      end

      # Nokogiri's MiniPortile port naming may say x86_64-linux because
      # extconf runs under the host baseruby. Verify the *contents*, not
      # the directory name: every archive member must be WASM or LLVM
      # bitcode. Refuse to combine native ELF objects into the WASI link.
      ar = crossruby.toolchain.ar
      archives.each do |archive|
        members, error, status = Open3.capture3(ar, "t", archive)
        raise "Cannot inspect #{archive}: #{error}" unless status.success?
        members.lines.map(&:strip).reject(&:empty?).each do |member|
          bytes, error, status = Open3.capture3(ar, "p", archive, member)
          raise "Cannot read #{member} from #{archive}: #{error}" unless status.success?
          magic = bytes.b.bytes.first(4)
          unless magic == [0, 97, 115, 109] || magic == [66, 67, 192, 222]
            raise "Non-WASM object #{member} (magic #{magic.inspect}) in #{archive}"
          end
        end
      end

      # The build root is independent of the Nokogiri gem source location.
      prefix = File.expand_path("wasi-dependencies", File.dirname(File.dirname(crossruby.build_dir)))
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

      # Supply the real WASI dependencies as normal static archives.
      # wasm-ld does not accept GNU --start-group/--end-group flags.
      # Keep the precise dependency ordering (exslt, xslt, xml2, gumbo,
      # lzma, zlib, iconv) rather than injecting unsupported linker options.
      list = linklist(crossruby)
      existing = File.readlines(list, chomp: true).reject(&:empty?)
      # Remove the linker-group block produced by older versions of this
      # adapter. Its contents are regenerated from the verified archives.
      if (start = existing.index("-Wl,--start-group"))
        finish_offset = existing[(start + 1)..].index("-Wl,--end-group")
        finish = start + 1 + finish_offset if finish_offset
        raise "Unterminated Nokogiri static link group" unless finish
        existing.slice!(start..finish)
      end
      probe = File.join(objdir, "libruby-static.a")
      # Old ruby.wasm runs persisted this temporary mkmf archive in
      # link.filelist. It is removed after extconf today, but the filelist
      # itself survives failed/retried builds. Drop ONLY this exact known
      # probe path, and continue rejecting unexpected Ruby archives.
      existing.delete(probe)
      if existing.any? { |entry| File.basename(entry) == "libruby-static.a" }
        raise "Unexpected Ruby static archive in Nokogiri final link list"
      end
      unless existing.any? { |entry| File.basename(entry) == "nokogiri.a" }
        raise "Nokogiri extension archive missing from final link list: #{existing.inspect}"
      end
      # Nokogiri's link.filelist persists across failed local builds.
      # Remove exactly the entries we manage before adding them back.
      managed = (archives + extras)
      existing.reject! { |entry| managed.include?(entry) }
      File.write(list, (existing + managed).join("\n") + "\n")
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
