---
name: plain-language-docs
description: The register for plans, runbooks, Linear tickets and PR descriptions — very short, technical, jargon translated at point of use, diagrams where they beat prose. Read when writing or rewriting a plan, release doc, ticket breakdown, or PR description that a teammate should understand on first read.
---

# Plain-language docs

Write for a competent engineer who hasn't seen this project. Technical, not dumbed down —
the simplification lives in the sentences, not the content.

## Register

- Name the mechanism, don't analogise: "kube DNS resolves the Service name", not "the
  cluster's phone book". At most one garnish metaphor per doc.
- Translate jargon at point of use, in one clause, keeping the real term once so it stays
  searchable: "a live, read-only window from one database into another (postgres_fdw)".
  After that, use the plain phrase — "the window".
- Numbers, not words: "13 callers", "~1h", "seconds".
- No filler: delete "in order to", "it's worth noting", "as mentioned above".
- The why is one clause, not a paragraph. If the rationale needs more, link it out.

## Shape

- The title names the actual work: "Reroute traffic without updating clients" — never
  "Next steps", "Get the code in", or any vague container.
- Lead with what happens and why it matters, in one or two sentences.
- Load-bearing facts get their own line: PR + branch, repos touched, the one timing line.
- Steps are checkboxes. Lists use bold labels, not tables — except a PR stack, which is
  a table (PR, branch, what it delivers).
- Categorise enumerations by the property that drives decisions (readers vs writers,
  patched vs rerouted), not alphabetically.

## Explaining concepts

One sentence, at the point where the reader needs it, stating what the thing does and the
one property that matters here:

- "A VirtualService is a per-service routing rule: match a URL prefix, strip it, forward."
- "The copy never overwrites — a record that already moved is skipped, so re-running is safe."
- "Applies in seconds and nothing restarts; rollback is deleting the resource."

Safety properties and rollback always get a line. "It must not X because Y" beats a design
essay. When an old design was replaced, one parenthetical names what it replaced — readers
arriving from stale links need the redirect.

## Condensing

Most messages are one sentence wearing five. Cut status framing, hedges, and reassurance
rituals; keep the fact, the date, and what the reader must do.

Before:

> Just a heads up that as part of the ongoing migration work, we're planning to make a
> change to how requests are routed. This will be applied at some point next week, and we
> don't currently anticipate any downtime. It's worth noting that no action is needed from
> your team at this stage. We'll be monitoring closely and will keep everyone updated, and
> please don't hesitate to reach out with any questions.

After:

> Next week we re-point request routing to the new service — no downtime expected, nothing
> for your team to do.

If a detail wouldn't change what the reader does next, it goes.

## Diagrams

When a mechanism has more than ~3 moving parts, embed the diagram next to the text (FigJam
section URL with node-id) instead of describing it. Draw with the figjam-diagrams skill;
when FigJam isn't available, render the diagram as an inline SVG or with whatever
visualisation the client can display in the conversation window — a drawn mechanism still
beats prose. For changes: a diagram where the dying route gets an ✕ and the new resource a
bright border beats any paragraph. Boxes carry titles and short mono facts; explanation
lives outside the boxes.
