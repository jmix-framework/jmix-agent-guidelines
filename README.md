# Jmix AI Agent Guidelines

This repository provides a collection of guidelines and "agent skills" designed to help AI coding agents develop applications using the [Jmix framework](https://www.jmix.io/) effectively.

The AI agent will use these resources to understand Jmix-specific patterns, mandatory rules, and best practices.

## Repository Structure

- `AGENTS.md`: General coding guidelines, architecture overview, and development workflow for Jmix projects.
- `skills/`: A collection of folders, each containing:
    - `SKILL.md`: Detailed instructions and rules for the agent regarding a specific Jmix feature.
    - Optional subdirectories with examples or other materials.

## How to Use

To enable these guidelines for your AI agent, follow these steps:

### 1. Project Guidelines

Copy the `AGENTS.md` file from this repository to the root of your Jmix application project. Depending on the agent you are using, you may need to rename it or place it in a specific folder:

- [Claude Code](https://code.claude.com/docs): Copy to the project root and rename to `CLAUDE.md`.
- [Codex](https://developers.openai.com/codex/cli): Copy to the project root and keep as `AGENTS.md`.
- [OpenCode](https://opencode.ai/docs): Copy to the project root and keep as `AGENTS.md`.
- [Junie](https://www.jetbrains.com/junie): Copy to the `.junie` project subdirectory and rename to `guidelines.md`.

### 2. Agent Skills

The `skills/` directory contains specialized knowledge for developing various Jmix features (entities, UI views, data access, etc.). These should be made available to the agent globally.

Copy or symlink the content of the `skills/` subdirectory to the folder recognized by your agent in your home directory:

| Agent       | Skills Folder Path           |
|:------------|:-----------------------------|
| Claude Code | `~/.claude/skills/`          |
| Codex       | `~/.codex/skills/`           |
| OpenCode    | `~/.config/opencode/skills/` |
| Junie       | `~/.junie/skills/` *         |

\* At the time of writing, the location of Junie global skills directory is not clear. See [JUNIE-1422](https://youtrack.jetbrains.com/issue/JUNIE-1422).

#### Example

Using symlink for Claude Code:
```bash
mkdir -p ~/.claude/skills
ln -s /path/to/jmix-agent-guidelines/skills/* ~/.claude/skills/
```

#### Agent Conventions Summary

| Agent       | Project Guidelines     | Home Directory Base   |
|:------------|:-----------------------|:----------------------|
| Claude Code | `CLAUDE.md`            | `~/.claude/`          |
| Codex       | `AGENTS.md`            | `~/.codex/`           |
| OpenCode    | `AGENTS.md`            | `~/.config/opencode/` |
| Junie       | `.junie/guidelines.md` | `~/.junie/`           |

### 3. MCP Servers

The following two MCP servers help AI agents to build Jmix apps:

- JetBrains (**highly recommended**): lets an external agent talk to a running IntelliJ IDEA to leverage code analysis and inspections.

- Context7 (optional): gives the agent docs and code examples from official sources.

To run the JetBrains MCP server in IntelliJ IDEA, go to **Settings → Tools → MCP Server** and select **Enable MCP Server ✓**.

Below are practical setup snippets per agent.

#### Claude Code

- JetBrains MCP:
    ```bash
    claude mcp add --transport sse jetbrains --scope user http://localhost:64342/sse
    ```

- Context7 MCP:
    ```bash
    claude mcp add context7 --scope user -- npx -y @upstash/context7-mcp --api-key YOUR_API_KEY
    ```

#### Codex

- JetBrains MCP:

  Open **Settings → Tools → MCP Server** and click **Copy Stdio Config** in **Manual Client Configuration** section. Paste the JSON into a text editor. You will see something like this:

    ```json
    {
      "type": "stdio",
      "env": {
        "IJ_MCP_SERVER_PORT": "64342"
      },
      "command": "<your path to java>",
      "args": [
        "-classpath",
        "<your very long classpath>",
        "com.intellij.mcpserver.stdio.McpStdioRunnerKt"
      ]
    }
    ```

  Open the terminal and run the following command using the values from the JSON:

    ```bash
    codex mcp add jetbrains --env IJ_MCP_SERVER_PORT=64342 -- "<your path to java>" -classpath "<your very long classpath>" "com.intellij.mcpserver.stdio.McpStdioRunnerKt"
    ```

- Context7 MCP:
    ```bash
    codex mcp add context7 -- npx -y @upstash/context7-mcp --api-key YOUR_API_KEY
    ```

#### OpenCode

Add to your `~/.config/opencode/opencode.json` (local servers):

```json
{
  "mcp": {
    "jetbrains": {
      "type": "remote",
      "url": "http://localhost:64342/sse",
      "enabled": true
    },
    "context7": {
      "type": "local",
      "command": ["npx", "-y", "@upstash/context7-mcp", "--api-key", "YOUR_API_KEY"],
      "enabled": true
    }
  }
}
```

#### Junie

- JetBrains MCP: not required. Junie runs inside the IntelliJ and already has native access to the IDE features.

- Context7 MCP: 
  
    Open **Settings → Tools → Junie → MCP Settings** and click **Add**. Paste the following JSON into the text field:

    ```json
    {
      "mcpServers": {
        "context7": {
          "command": "npx",
          "args": ["-y", "@upstash/context7-mcp", "--api-key", "YOUR_API_KEY"]
        }
      }
    }  
    ```