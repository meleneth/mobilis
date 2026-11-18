# frozen_string_literal: true

# Mobilis historically shares its native entrypoint with the unrelated
# JobesWar diagram demo, which pulls terminal-only gems. The browser runtime
# loads the Mobilis portion of that canonical require list while preserving the
# same implementation files and marks the native entrypoint as satisfied for
# downloaded definitions that begin with `require "mobilis"`.
mobilis_entrypoint = File.expand_path("../mobilis.rb", __dir__)
mobilis_loader = File.readlines(mobilis_entrypoint).drop(7).join
eval(mobilis_loader, TOPLEVEL_BINDING, mobilis_entrypoint, 8) # rubocop:disable Security/Eval
$LOADED_FEATURES << mobilis_entrypoint unless $LOADED_FEATURES.include?(mobilis_entrypoint)
