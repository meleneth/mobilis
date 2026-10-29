decide whether DSL names should resolve by raw input name, normalized node name, or both
add a non-materializing DSL entrypoint for tests and inspection
verify/fix Compose::Volume base merging for overrides
tighten AutoVivify#merge! deep behavior or document its limits
fix RefSlot#hydrate_refs! and add a spec that hydrates from IDs only
prevent a second materialization from recursively deleting an existing generated project's runtime data; fail before modifying output when `generate/` exists (PostgreSQL 18 creates root-owned files under `data/<environment>/<db>/18/docker`), and test the failure path without touching the data
