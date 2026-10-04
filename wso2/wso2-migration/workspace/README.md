# Workspace

This is your working area. Drop your files here, then open this project in Claude Code and follow the CLAUDE.md guide to generate your migration scripts.

## What Goes Where

| Directory | What to put here |
|---|---|
| `migration-docs/` | The WSO2 migration documentation provided by WSO2 Support (Markdown or PDF) |
| `apim_packs/` | The target APIM pack ZIP — e.g. `wso2am-4.5.0.5.zip` |
| `migration-artifacts/is/` | IS migration client ZIP — e.g. `wso2is-migration-x.x.x.zip` |
| `migration-artifacts/apim/` | APIM migration client ZIP — e.g. `wso2am-migration-x.x.x.zip` |
| `migration-artifacts/db-scripts/` | DB scripts provided with the migration client (MySQL.sql, PostgreSQL.sql, etc.) |
| `configurations/` | Your migrated `deployment.toml` for the target version, the JDBC driver JAR, and any custom config files |
| `configurations/security/` | Your source-version JKS keystore files (never committed to Git) |
| `customizations/` | Optional. UI customization builds (e.g. `devportal-dist/`) and theme files |
| `customizations/custom_handlers/` | Optional. Custom handler / mediator JARs |
| `generated-scripts/` | Claude generates your migration scripts here (with their own `lib/`) |
| `db_dumps/` | Created by Script 1 — `source` and `post-is` snapshots land here |

## Steps

1. Drop all your files into the directories above
2. Open this project in Claude Code:
   ```bash
   claude
   ```
3. Run the generation command:
   ```
   /generate-migration-scripts
   ```
4. Claude will ask you clarifying questions, then generate all scripts in `generated-scripts/`
5. Review the generated scripts before running them
