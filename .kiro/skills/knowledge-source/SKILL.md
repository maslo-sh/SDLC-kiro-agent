---
name: knowledge-source
description: Search and read best-practice guidance from the configured knowledge source; defaults to the current workspace's docs, pluggable to a wiki or Datadog.
version: "1.0"
---

# Knowledge Source Skill

The Knowledge Source skill is the interface the **Researcher** uses to retrieve best-practice
information while preparing a Research Brief. It is a **documented operation contract**, not
executable code: v1 of the council is runtime-free, so each operation below is a named capability
with defined inputs, outputs, and meaning that a hosting harness (or a human) fulfills.

A different knowledge source (a wiki, a documentation service, Datadog, a search index) can be
plugged in later by fulfilling the same `search` / `read` contract — without changing any agent's
role. Point the source at a new location by editing the **Default source** section at the bottom of
this file (and, if it needs extra tools, adding them to `.kiro/agents/researcher.json`).

## Operations

| Operation | Input | Output | Meaning |
|-----------|-------|--------|---------|
| `search(query)` | free-text query / topic keywords describing the ticket topic | list of note references, each a `{ id, title }` pair (may be empty) | Find best-practice notes relevant to the ticket topic |
| `read(reference)` | a note reference/id returned by `search` | the note content as Markdown | Retrieve the full text of a single knowledge note |

### `search(query)`

- **Input:** A free-text query — typically topic keywords drawn from the framed ticket (for
  example, `"error handling"` or `"input validation"`).
- **Output:** A list of note references. Each reference identifies one matching note by an `id`
  (used to `read` it) and a human-readable `title`. When nothing matches, the list is empty.
- **Meaning:** Locate the best-practice notes that are relevant to the ticket topic so the
  Researcher can decide which ones to read.

### `read(reference)`

- **Input:** A single note reference/id, as returned by `search`.
- **Output:** The full note content as Markdown.
- **Meaning:** Retrieve the complete text of one knowledge note so its guidance can be summarized
  and cited in the Research Brief.

## Default: the current workspace's own docs

The default implementation searches the **documentation already in the current workspace** — no
index, service, or seed content is required.

- Treat Markdown docs in the workspace (READMEs, `docs/`, ADRs, design notes) as the knowledge base.
- `search(query)` — match the query keywords against the **filenames, titles, and headings** of
  those docs (using the `grep`/`glob` tools), and return a reference (`id` = the file path,
  `title` = the doc's heading) for each matching file.
- `read(reference)` — return the **contents of the referenced Markdown file**.

If nothing matches a query, `search` returns an empty list; the Researcher records "no guidance
found" in the Research Brief's Sources section rather than failing.

## Concrete integration example (wiki / Datadog)

The workspace-docs default is only one way to fulfill the contract. A wiki- or Datadog-backed source
satisfies the **same** `search` / `read` operations, so no change to the Researcher's role is needed
— only which source it reads from (and the tools it needs to reach that source) changes.

| Operation | Wiki / Datadog mapping |
|-----------|------------------------|
| `search(query)` | Call the source's **search API** with the query keywords (e.g. a wiki full-text search, or a Datadog dashboards/notes search). Map each hit to a `{ id, title }` reference, where `id` is the page/dashboard identifier and `title` is its display name. An empty result set maps to an empty list. |
| `read(reference)` | **Retrieve the content of the referenced page or dashboard** by its id (e.g. fetch the wiki page body, or the Datadog dashboard/notebook content) and return it as Markdown for the Researcher to summarize and cite. |

Because the Researcher only ever calls `search(query)` and `read(reference)`, swapping the local-file
default for a wiki or Datadog source is purely a matter of fulfilling this contract for that source.

## Default source

Unless you change it, the **default described above applies**: the `researcher` agent searches the
current workspace's own docs with its `read`/`grep`/`glob` tools. No configuration or seed content is
required for the pipeline to work out of the box.

To use a different source (a wiki, documentation service, or search index), fulfill the same
`search` / `read` contract against it and give the `researcher` agent
(`.kiro/agents/researcher.json`) the tools it needs to reach that source (for example, an MCP server
for the wiki or Datadog). No other agent changes are needed.
