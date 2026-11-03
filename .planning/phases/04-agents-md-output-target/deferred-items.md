# Phase 04 Deferred Items

- **TOC treats `#` lines inside fenced code as headings (pre-existing, all targets).** With `-t`, `TOCGenerator.extract_headers_from_content` lists `# deploy comment` from a fenced bash block as a TOC entry, and `add_anchor_ids_to_content` inserts an `<a id=...>` line inside the fence. Seen during 04-01 on the AGENTS.md fixture; the same code path runs for claude and cursor (unchanged per D-08). Fix belongs in `lib/ruly/services/toc_generator.rb` with fence tracking.
- **TOC anchors for `requires:` targets use absolute paths (pre-existing).** A required rule's TOC anchor embeds its resolved absolute path (e.g. `#tmp-...-rules-base-base-rule`), so anchors differ per machine. Same path for every target.
