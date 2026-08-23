---
name: direnv
description: Use direnv to manage project-specific environment variables for bash commands.
version: 0.1.0
author: omp-plugins
type: skill
category: development
tags:
  - direnv
  - environment
  - bash
  - shell
---

# Direnv Skill

> **Purpose**: Automatically load and use direnv environment variables when executing bash commands in the agent.

## What direnv does

direnv is an environment switcher that loads `.envrc` or `.env` files when you enter a directory. It manages project-specific environment variables like:
- PATH modifications (e.g., adding virtual environments)
- Database connection strings
- API keys and secrets
- Build tool configurations
- Any other environment variables

## How this plugin works

The direnv plugin automatically:

1. **Detects** `.envrc` or `.env` files in the current directory or parent directories
2. **Loads** the environment via `direnv export bash`
3. **Injects** the loaded variables into the agent's system prompt
4. **Instructs** the agent to pass these variables via the `env` parameter of the `bash` tool

## Usage

### Automatic

When you start a session in a project with a `.envrc` file, the plugin automatically detects and loads the environment. You don't need to do anything — just use the `bash` tool as normal, and the direnv environment variables will be available.

### Querying the environment

Use the `direnv_env` tool to see what environment variables are currently loaded:

```
Call tool: direnv_env()
```

This returns the directory where the `.envrc` was found and all exported environment variables.

### Reloading after changes

If you modify the `.envrc` file, use the `direnv_reload` tool to pick up changes:

```
Call tool: direnv_reload()
```

### Manual direnv allow

If direnv hasn't been allowed for a directory, you may need to run:

```bash
direnv allow .
```

## Bash tool usage

When the direnv environment is loaded, the agent should pass the environment variables via the `env` parameter:

```json
{
  "tool": "bash",
  "input": {
    "command": "python manage.py runserver",
    "env": {
      "DATABASE_URL": "postgres://localhost/mydb",
      "SECRET_KEY": "...",
      "PATH": "/path/to/venv/bin:/usr/bin:/bin"
    }
  }
}
```

Or use `direnv exec` to run a command with the full direnv environment:

```json
{
  "tool": "bash",
  "input": {
    "command": "direnv exec . python manage.py runserver"
  }
}
```

## Troubleshooting

### "direnv is not installed"

Install direnv:
- NixOS: `nix-env -iA nixos.direnv` or add to `environment.systemPackages`
- macOS: `brew install direnv`
- Linux: `sudo apt install direnv` or use your package manager

### "direnv is not allowed"

Run `direnv allow` in the directory containing the `.envrc` file:

```bash
direnv allow /path/to/project
```

### Environment not loading

1. Check that `.envrc` exists: `ls -la .envrc`
2. Check direnv status: `direnv status`
3. Try loading manually: `direnv export bash`
4. Allow if needed: `direnv allow`
