# Moon Unit Missions

A collection of automated AI agent workflows powered by [Moon Units](docs/moon-units-overview.md) — GoDaddy's internal platform that runs Claude agents in disposable Docker containers.

## Prerequisites

- `mu` CLI ([installation guide](docs/moon-units-installation.md))
- Docker (`colima start`)
- AWS credentials (non-PCI account)
- `~/.config/mu/mu.env` with MOONUNIT_* credentials

## Repository Structure

```
missions/           # Each subdirectory is a self-contained mission
docs/               # Moon Units platform documentation
```

Each mission has its own README with usage instructions and configuration details.

## How It Works

1. Edit a config YAML under `missions/<mission>/config/` with your target parameters
2. Run the mission's launcher script
3. The AI agent executes multi-stage work inside a disposable Docker container
4. Output is automatically pulled on completion
5. macOS notification fires when done

## Documentation

- [Moon Units Overview](docs/moon-units-overview.md) — What Moon Units is and why it exists
- [Moon Units Concepts](docs/moon-units-concepts.md) — Manifests, stages, plans, triggers
- [Installation Guide](docs/moon-units-installation.md) — Setting up the mu CLI
