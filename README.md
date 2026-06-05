# Combat

An open-source Roblox combat game built for educational purposes; a reference implementation of common game combat systems written in Luau.

The project is a personal learning exercise and a resource for other developers who want to understand how real combat mechanics are structured. I do not claim to be an expert, nor do I write code like one.

Once upon a time I wanted to create a wonderful combat system, though learning to do so was a task. And so, years later "Combat" was born.

## Goals

- Keep each system modular and easy to read in isolation
- Serve as a living reference for Roblox game architecture patterns

## Architecture

The project uses [Rojo](https://github.com/rojo-rbx/rojo) for file sync and [Wally](https://github.com/UpliftGames/wally) for package management.

## Getting Started

**Prerequisites:** [Rojo 7.x](https://rojo.space), [Wally](https://github.com/UpliftGames/wally), Roblox Studio.

```bash
# Install Wally packages
wally install

# Build the place file
rojo build -o "Combat.rbxlx"
```

Open `Combat.rbxlx` in Roblox Studio, then start the live-sync server:

```bash
rojo serve
```

## Dependencies

| Package | Purpose |
|---|---|
| [evaera/cmdr](https://github.com/evaera/Cmdr) | Developer command console |
| [howmanysmall/janitor](https://github.com/howmanysmall/Janitor) | Connection and instance cleanup |

## Linting

[Selene](https://github.com/Kampfkarren/selene) is configured for the Roblox standard library:

```bash
selene src/
```