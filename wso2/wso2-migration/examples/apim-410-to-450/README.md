# Example: APIM 4.1.0 → 4.5.0 Migration Scripts

This is a reference implementation showing what fully-generated migration scripts look like for the APIM 4.1.0 to 4.5.0 upgrade path.

Use this to understand the expected structure and script conventions before generating your own.

## What's Here

| File/Directory | Description |
|---|---|
| `migration.config.sh` | Central config — all environment variables in one place |
| `scripts/1_db_dump.sh` | Dump source APIM and shared databases |
| `scripts/2_db_restore.sh` | Restore DB from backup on target environment |
| `scripts/3_prepare_target_pack.sh` | Unzip, U2 update, copy configs and customizations |
| `scripts/4_prep_is_migration.sh` | Prepare IS 5.11.0 → 6.0.0 migration (DB script + client setup) |
| `scripts/5_cleanup_is_artifacts.sh` | Remove IS migration artifacts after server run |
| `scripts/6_prep_apim_migration.sh` | Prepare APIM migration client + pre-migration validation |
| `scripts/7_cleanup_apim_artifacts.sh` | Remove APIM artifacts + print post-migration guidance |
| `configurations/` | Example deployment.toml and velocity template |

## Script Execution Order

```
1_db_dump.sh           ← Run on SOURCE environment
        ↓
2_db_restore.sh        ← Run on TARGET environment (reset for each migration run)
        ↓
3_prepare_target_pack.sh
        ↓
4_prep_is_migration.sh → [Manual: sh api-manager.sh -Dmigrate -Dcomponent=identity]
        ↓
5_cleanup_is_artifacts.sh
        ↓
6_prep_apim_migration.sh → [Manual: sh api-manager.sh -Dmigrate -DmigrateFromVersion=4.1.0]
        ↓
7_cleanup_apim_artifacts.sh  → Follow post-migration guidance output
```

## Key Conventions

- Scripts **never** automate server startup for migration — they print the exact commands as `[WARN] Next Steps`
- All environment values come from `migration.config.sh` — nothing is hardcoded
- `jq` is used for JSON editing, `yq` for YAML editing — never `sed`/`awk` for structured data
- Optional sections (UI customizations, custom handlers, JKS) are controlled by `ENABLE_*` flags in config
