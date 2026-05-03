# agent-guider

A collection of step-by-step setup guides written for AI coding agents — primarily [Claude Code](https://claude.ai/code).

Each guide is a structured markdown file that an AI agent can read and execute. Instead of copy-pasting commands, you hand the guide to your agent, answer a few questions, and it handles the setup — checking prerequisites, confirming before every action, and verifying each step before moving on.

---

## How to Use

```bash
# Clone the repo
git clone https://github.com/ramiiyan/agent-guider.git

# Open Claude Code in the guide folder
cd agent-guider/<guide-name>
claude

# Inside Claude Code, hand it the guide
> read SETUP_GUIDE.md and follow it to set up the environment
```

Claude Code will ask for your specific paths and config, then drive the full setup with your confirmation at each step.

---

## Guides

| Guide | What it sets up | Blog post |
|---|---|---|
| [wso2-mi-ibmmq](./wso2/wso2-mi-ibmmq/SETUP_GUIDE.md) | WSO2 Micro Integrator 4.x connected to IBM MQ via JMS Inbound Endpoint | [Read on Medium](https://medium.com/@ramiiyan.sriraguhan/connecting-ibm-mq-with-wso2-mi-the-hard-way-and-the-ai-way-c543391dabfd) |

---

## Guide Design Principles

Each `SETUP_GUIDE.md` in this repo follows the same conventions:

- **Ask first, act second** — the agent collects all required paths and config upfront before touching anything
- **Confirm before every action** — every command run and file write requires explicit user confirmation
- **Verify each step** — the agent checks the outcome of each step before proceeding
- **Fail gracefully** — if something goes wrong, the agent surfaces the error and asks how to continue rather than blindly moving on

---

## Contributing

Adding a new guide? Create a folder named after the setup (e.g. `choreo-redis/`) and add a `SETUP_GUIDE.md` following the same conventions. Open a PR and add a row to the table above.

---

*Guides tested on macOS (Apple Silicon) unless noted otherwise.*
