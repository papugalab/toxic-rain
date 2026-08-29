# ADR-0002: Attach the canonical project to the Toxic Rain cloud place

- Status: Accepted
- Date: 2026-08-26
- Deciders: Project maintainers
- Supersedes: ADR-0001 cloud-identity decision and its ownership of `default.project.json`
- Superseded by: None

## Context

Project initialization deliberately left cloud identity unresolved. The user
then created the new Toxic Rain destination in Roblox Studio and authorized it
for this independent game.

The only connected Studio Edit DataModel after creation authoritatively
reported:

- `game.PlaceId = 79356340322631`;
- `game.GameId = 10762145525`;
- `game.CreatorId = 4364136284`;
- `game.CreatorType = Enum.CreatorType.User`.

The observed DataModel name was `Place1`; names are mutable presentation and
are not used as cloud identity evidence.

## Decision

Attach the Toxic Rain repository to Place `79356340322631` in Experience
`10762145525`. Record those exact observed positive integers as top-level
`placeId` and `gameId` in `default.project.json` and restrict live sync to the
single approved destination through `servePlaceIds = [79356340322631]`.

The canonical local `place.rbxl` remains the binary scene source. Cloud names
do not select the project or override the stable ID pair.

## Alternatives considered

### Keep cloud identity unresolved

Rejected because the user created the destination and its exact identity is
now directly observable from the selected post-creation DataModel.

### Infer identity from the requested Toxic Rain name

Rejected because Roblox names are mutable and the DataModel currently reports
`Place1`; only the exact observed IDs are authoritative.

### Permit additional live-sync destinations

Rejected because no other Toxic Rain place has been created, observed, or
authorized.

## Consequences

### Positive

- Studio selection and Rojo live sync fail closed to the exact Toxic Rain
  destination.
- Future cloud-dependent checks can verify stable IDs instead of mutable names.
- Template validation places cannot be targeted by this derived repository.

### Negative

- Replacing the place or adding another approved sync destination requires a
  new superseding project decision.
- Opening the canonical local file requires the verified Rojo connection to
  restore these IDs before cloud-dependent operations.

## Template divergence

- Upstream baseline: `fbc34584f1495d388bce2159e9a45c9c57fd9abc`
- Paths:
  - `default.project.json`
- Project invariant: `name` remains `rain`, `servePort` remains absent, and
  `placeId`, `gameId`, and `servePlaceIds` preserve exactly `79356340322631`,
  `10762145525`, and `[79356340322631]` respectively.
- Upstream merge policy: reconcile compatible incoming mappings and settings
  while preserving the exact project name and cloud identity fields and
  removing any incoming `servePort` or template validation IDs.
- Removal condition: only after an explicitly authorized replacement cloud
  destination is observed and a new project ADR supersedes this decision.

## Enforcement

- Agent rules: `AGENTS.md`, `.agents/rules/rojo-project.md`,
  `.agents/rules/project-initialization.md`,
  `.agents/rules/architecture-decisions.md`
- Current documentation: `README.md`, `docs/adr/README.md`
- Code boundaries: `default.project.json`, canonical `place.rbxl`
- Tests: repository-layout validation, two consecutive Rojo preflights,
  exact selected-DataModel identity verification, temporary Rojo build
