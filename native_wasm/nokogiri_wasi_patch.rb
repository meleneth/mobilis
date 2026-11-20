# frozen_string_literal: true

# Loaded only by Nokogiri extconf through the ruby.wasm baseruby.
# It applies a checked, narrow patch to *extracted* libxml2 2.13.9,
# before MiniPortile invokes configure/compile. No installed gem edits.
require "mini_portile2"

module MobilisWasiLibxml2Patch
  def patch
    super
    return unless name == "libxml2" && version == "2.13.9"

    # Legacy mode enables libxml2's own HTTP/FTP transports by default.
    # WASI SDK 24 lacks POSIX sockets, so these cannot compile or run.
    # Keep zlib, LZMA, HTML, XML and memory-backed parsing enabled.
    # MiniPortile caches configure options, so changed options trigger
    # reconfiguration instead of reusing the old Makefile.
    ["--without-http", "--without-ftp"].each do |option|
      configure_options << option unless configure_options.include?(option)
    end

    file = File.join(send(:work_path), "xmlIO.c")
    raise "Missing expected libxml2 source: #{file}" unless File.file?(file)
    source = File.binread(file)
    return if source.include?("MOBILIS_WASI_NO_DUP")

    # xmlInputFromFd needs a *duplicated* descriptor because libxml2 closes
    # its input. Borrowing the caller's fd would silently transfer ownership.
    begin_anchor = "xmlInputFromFd(xmlParserInputBufferPtr buf, int fd, int unzip) {\n"
    end_anchor = "    return(XML_ERR_OK);\n}\n\n/**\n * xmlInputDefaultOpen:"
    output_anchor = "        fd = dup(STDOUT_FILENO);\n\n        if (fd < 0)\n            return(xmlIOErr(0, \"dup()\"));"

    unless source.scan(begin_anchor).length == 1 &&
           source.scan(end_anchor).length == 1 &&
           source.scan(output_anchor).length == 1
      raise "Unexpected libxml2 2.13.9 xmlIO.c; refusing unsafe WASI patch"
    end

    source.sub!(begin_anchor, begin_anchor + <<~C)
    #ifdef __wasi__ /* MOBILIS_WASI_NO_DUP */
        (void) buf;
        (void) fd;
        (void) unzip;
        return(xmlIOErr(ENOSYS, "dup() unavailable on WASI"));
    #else
    C
    source.sub!(end_anchor, "    return(XML_ERR_OK);\n#endif /* __wasi__ */\n}\n\n/**\n * xmlInputDefaultOpen:")
    source.sub!(output_anchor, <<~C.chomp)
    #ifdef __wasi__
            return(xmlIOErr(ENOSYS, "stdout descriptor duplication unavailable on WASI"));
    #else
            fd = dup(STDOUT_FILENO);

            if (fd < 0)
                return(xmlIOErr(0, "dup()"));
    #endif
    C

    File.binwrite(file, source)
    warn "Applied checked WASI fd-ownership patch to #{file}"
  end
end

MiniPortile.prepend(MobilisWasiLibxml2Patch)
