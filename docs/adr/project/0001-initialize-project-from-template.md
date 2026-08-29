# ADR-0001: Initialize Toxic Rain from the Roblox project template

- Status: Accepted
- Date: 2026-08-26
- Deciders: Project maintainers
- Supersedes: None
- Superseded by: None

## Context

Toxic Rain is a new cooperative Roblox survival game with its own repository,
scene, cloud identity, gameplay, and product decisions. It is unrelated to the
Factory game. The project needs the reusable initialization, save,
communication, testing, Rojo, and feature-development infrastructure from the
Roblox project template while remaining able to receive future upstream
updates safely.

The repository is `https://github.com/papugalab/toxic-rain`; its template
upstream baseline is `fbc34584f1495d388bce2159e9a45c9c57fd9abc`. The stable
local repository directory and Rojo connection name are `rain`.

No Toxic Rain place has been published or attached yet. The template's cloud
identity is therefore removed and the project's cloud identity remains
unresolved until an authorized Studio attachment provides exact nonzero
`game.PlaceId` and `game.GameId` values.

## Decision

Initialize Toxic Rain as a derived game repository with `origin` pointing to
the game repository and `upstream` pointing to the reusable template.

Use `rain` as the Rojo connection name and the shared default endpoint
`127.0.0.1:34872`. `servePort` remains absent. Until Studio supplies and the
project verifies its own cloud identity, top-level `placeId`, `gameId`, and
`servePlaceIds` remain absent as one complete unresolved set.

The inherited `place.rbxl` is the initial canonical scene. From this decision
forward, its complete binary content belongs to Toxic Rain and wins on future
template updates; scene changes are made only through Roblox Studio.

The project starts at application version `1.0.0`. Studio continues to use
memory storage. Production persistence compatibility, DataStore naming, scope,
prefix, and limits remain at the safe template defaults until product and
release requirements justify a separate decision. Wallet currencies and
defaults also remain template defaults as dormant infrastructure; the initial
prototype does not expose an economy, shop, progression, or purchases.

The GDD's service examples describe gameplay responsibility boundaries, not
permission to add direct gameplay remotes, a second player-lifecycle owner, or
standalone startup scripts. New gameplay must compose through the inherited
manifests, Communication modules, and PlayersModule.

Unresolved choices are the published Experience/place identity, production
DataStore policy, released-save migration baseline, final economy, and any
multi-place topology. They require later explicit project decisions when the
corresponding work begins.

## Alternatives considered

### Copy files without shared Git history

Rejected because future template updates would lose a reliable merge base and
become manual migrations.

### Retain the template validation PlaceIds

Rejected because those IDs belong only to the template's validation
Experience and could live-sync or publish against the wrong destination.

### Invent production economy and persistence settings now

Rejected because the prototype GDD explicitly postpones economy and does not
define released-data compatibility requirements.

## Consequences

### Positive

- Toxic Rain has an independent repository, feature namespace, scene, and
  future cloud identity.
- The project can receive reviewed template updates through normal Git history.
- Roblox Studio connections are distinguishable by the stable `rain` name.
- Prototype work can start without prematurely committing to an economy or
  production persistence contract.

### Negative

- Publishing requires a follow-up ADR and exact identity capture from Studio.
- Template-owned paths intentionally changed here must remain reconciled on
  every upstream update.
- The inherited infrastructure is broader than the first greybox prototype.

## Template divergence

- Upstream baseline: `fbc34584f1495d388bce2159e9a45c9c57fd9abc`
- Paths:
  - `README.md`
  - `default.project.json`
  - `place.rbxl`
- Project invariant: `README.md` describes Toxic Rain and its workflow;
  `default.project.json` keeps `name` equal to `rain`, keeps `servePort`
  absent, and keeps all cloud identity fields absent until independently
  verified; `place.rbxl` is the project's complete canonical scene.
- Upstream merge policy: reconcile useful incoming README and JSON changes
  while preserving the project identity and removing any incoming
  `servePort` or template cloud IDs; always keep the complete project
  `place.rbxl` and replay desired upstream scene changes manually in Studio.
- Removal condition: only when the project is no longer derived from this
  template and no longer uses its hybrid Rojo/Studio ownership model.

## Enforcement

- Agent rules: `AGENTS.md`, `.agents/rules/project-initialization.md`,
  `.agents/rules/template-updates.md`, `.agents/rules/rojo-project.md`,
  `.agents/rules/architecture-decisions.md`
- Current documentation: `README.md`,
  `TOXIC RAIN — GDD И ТЕХНИЧЕСКИЕ ПРАВИЛА ПРОЕКТА.md`, `docs/adr/README.md`
- Code boundaries: `default.project.json`, `place.rbxl`,
  `docs/Features/project/`
- Tests: `scripts/validate-repository-layout.ps1`,
  `scripts/validate-feature-workflow.ps1`, Rojo validation build, two
  consecutive `scripts/ensure-rojo-server.ps1` runs
