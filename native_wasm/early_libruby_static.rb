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
      super
    end
  end
end

RubyWasm::CrossRubyProduct.prepend(
  MobilisEarlyRubyArchive::CoreBeforeGemExtensions
)
RubyWasm::CrossRubyExtProduct.prepend(
  MobilisEarlyRubyArchive::LinkRealArchiveInMkmfProbes
)
