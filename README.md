# agent-guider

A collection of step-by-step setup guides written for AI coding agents — primarily [Claude Code](https://claude.ai/code).

Each guide is a structured markdown file that an AI agent can read and execute. Instead of copy-pasting commands, you hand the guide to your agent, answer a few questions, and it handles the setup — checking prerequisites, confirming before every action, and verifying each step before moving on.

---

## How to Use

```bash
# Clone the repo
git clone https://github.com/ramiiyan/agent-guider.git

# Open Claude Code in the guide folder
cd agent-guider/<guide-folder>
claude
```

Each guide folder says how to start it:

- **Setup guides** have a `SETUP_GUIDE.md` — inside Claude Code: `> read SETUP_GUIDE.md and follow it to set up the environment`. Claude asks for your paths and config, then drives the setup with your confirmation at each step.
- **Toolkits** have a `CLAUDE.md` and a slash command — inside Claude Code, run the command listed in the guide's README (e.g. `/generate-migration-scripts`). Claude reads your inputs, asks a few questions, and generates files for you to review and run.

---

## Guides

| Guide | What it sets up | Blog post |
|---|---|---|
| [wso2-mi-ibmmq](./wso2/wso2-mi-ibmmq/SETUP_GUIDE.md) | WSO2 Micro Integrator 4.x connected to IBM MQ via JMS Inbound Endpoint | [Read on Medium](https://medium.com/@ramiiyan.sriraguhan/connecting-ibm-mq-with-wso2-mi-the-hard-way-and-the-ai-way-c543391dabfd) |
| [wso2-migration](./wso2/wso2-migration/README.md) | Generates WSO2 APIM data migration scripts (with DB checkpoints) from your WSO2 migration guide — run `/generate-migration-scripts` | [Read on Medium](https://medium.com/@ramiiyan.sriraguhan/automating-wso2-apim-data-migration-treat-the-runbook-like-code-with-checkpoints-352bb199b6c8) |

---

## Guide Design Principles

Each guide in this repo follows the same conventions:

- **Ask first, act second** — the agent collects all required paths and config upfront before touching anything
- **Confirm before every action** — every command run and file write requires explicit user confirmation
- **Verify each step** — the agent checks the outcome of each step before proceeding
- **Fail gracefully** — if something goes wrong, the agent surfaces the error and asks how to continue rather than blindly moving on

---

## Contributing

Adding a new guide? Create a folder named after the setup (e.g. `choreo-redis/`) and add a `SETUP_GUIDE.md` (or a `CLAUDE.md` + slash command for a toolkit) following the same conventions. Open a PR and add a row to the table above.

---

*Guides tested on macOS (Apple Silicon) unless noted otherwise.*
