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
      File.symlink(archive, link)
      # ruby.wasm clears RUBYOPT for the baseruby extconf invocation.
      # Scope a preload to Nokogiri's extconf only so MiniPortile can apply
      # our WASI libxml2 source patch immediately after extraction.
      if name.include?("nokogiri-")
        super(MobilisEarlyRubyArchive::NokogiriExecutor.new(executor), crossruby)
      else
        super
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
