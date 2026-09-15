---
name: quality-gate
description: The Reviewer's Definition-of-Done quality gate: tests present, documentation updated, security basics.
---

# Quality Gate — Definition of Done

This skill supplies the Reviewer's Definition-of-Done. The Reviewer evaluates every ticket against
each item below and records each item's result in the Review Report's **Quality Gate Results**
section. The item titles correspond one-to-one with the rows in the Review Report
template, keeping the two documents consistent.

## Definition-of-Done Items

- **Tests present** — Automated tests exist for the implemented change and pass.
- **Documentation updated** — User- or developer-facing docs reflect the change.
- **Security basics addressed** — Input validation, secret handling, and error handling are sound for the     change; no obvious injection or exposure risks.
- **Alignment with rest of source code** - implemented modifications should follow general style
of the source code.

## Recording Results

When the Reviewer completes a review, the Reviewer records the result (Pass / Fail / N-A) of each
item above in the Review Report's Quality Gate Results section, one row per item.
