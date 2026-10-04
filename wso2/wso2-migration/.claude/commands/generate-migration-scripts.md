Follow the migration script generation guide in CLAUDE.md.

Start immediately with Phase 1 — scan the entire `workspace/` directory before doing anything else.

If `workspace/migration-docs/` is empty, stop and tell the user:
> "No migration documentation found. Please drop your WSO2 migration docs (provided by WSO2 Support) into `workspace/migration-docs/` and run this command again."

Otherwise, proceed through all three phases as defined in CLAUDE.md:
1. **Phase 1** — Scan the entire `workspace/` directory: read all files in `migration-docs/` for content, and inventory everything else for presence (ZIPs, JKS files, deployment.toml, customization files). Summarise what you found before asking anything.
2. **Phase 2** — Ask questions in 4 conversational groups (Database → Infrastructure → Customizations → IS Migration), waiting for the user's answer after each group before asking the next. Do not generate scripts until all groups are answered.
3. **Phase 3** — Generate all 9 files into `workspace/generated-scripts/` (README.md + migration.config.sh + 7 scripts), copy the four `lib/*.sh` helpers into `workspace/generated-scripts/lib/` yourself, then print the closing summary message.
