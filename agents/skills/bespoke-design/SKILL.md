---
name: bespoke-design
description: Design and build bespoke presentations, slide decks, browser presentations and websites through a guided interview, random-string concept exploration and visual refinement. Use when the user wants a beautiful, distinctive result shaped around their taste, wants to explore or reroll design directions, or invokes bespoke-design. Covers the brief, narrative, typography, imagery, motion, implementation and delivery.
---

# Bespoke design

Turn the user's subject and taste into a finished presentation or website.
Default to a guided conversation followed by a working artifact. A brief alone
is the deliverable only when the user requests one.

## Interview without exhausting the user

Read [the question bank](references/questions.md) before interviewing. Work
through the relevant topics in rounds of at most 3 questions. Reuse answers
already present in the conversation or source material. Offer concrete choices
and a recommendation when useful; accept "you decide" and "surprise me".

Start with the missing essentials:

- **Purpose:** what is the subject, and what should the audience understand or do?
- **Audience:** who is it for, and what do they already know?
- **Delivery:** a live slide deck, a document to read, a browser presentation, a
  website, or a combination? What is the deadline and approximate size?

Next establish taste and constraints, then ask the questions specific to the
chosen medium. Offer the remaining relevant topics as a short checklist so the
user can surface overlooked needs. "Full interview" means covering every
applicable topic over several rounds. "Quick start" means asking only what
would change the result and proposing the rest as assumptions.

Use the host's question tool when available, otherwise ask in chat. Missing
source facts stay open; aesthetic preferences can be delegated. A user who has
delegated choices should not have to approve each minor decision.

## Establish the brief and delivery route

Summarise the purpose, audience, story, desired feeling, content sources,
non-negotiables, output format and open questions. Separate explicit decisions
from assumptions. Resolve conflicting requirements before building on them.

Propose a small build plan covering concept previews, the full artifact and
verification. Observe the user's working agreements about editing files; once
the plan is authorised, routine revisions within it need no further approval.
Record the brief and subsequent decisions in `design-brief.md` in the project
workspace, never in this skill's directory. Reuse an existing project brief.

Load the relevant implementation skill when available:

- **Slides:** Presentations for PowerPoint or Google Slides, including rendering
  and editable output. Confirm the actual target application and export format.
- **Website:** Sites for a new website; follow the established project workflow
  when editing an existing codebase. Agree the hosting destination before launch.
- **Browser presentation:** use an appropriate web workflow, with slide
  navigation, fullscreen and a printable fallback if requested.
- **Figma:** load the applicable Figma skills when Figma is the chosen surface.
- **PDF:** use the PDF workflow for inspection of a requested final PDF.

Check that required tools and exports are available before promising them. If a
format is unavailable, explain the limitation and offer a usable alternative.
Carry the brief into the implementation workflow; do not restart its interview.

## Explore with random strings

Run the bundled generator, resolving the path relative to this skill:

```sh
python3 "<skill-directory>/scripts/generate-seeds.py" --count 3
```

It emits JSON containing independent alphanumeric strings from Python's
`secrets` module. Use one per candidate. If Python is unavailable, use a
supported runtime's secure random API and record that substitution. Never
describe a string invented in prose as tool-generated randomness.

Use the string to stimulate palette, type, layout and image ideas; keep it out
of the finished artifact. This is a creative input, not a guarantee of quality
or repeatable model output. Brand rules, factual accuracy and usability win
over any association it suggests.

Create 3 candidate directions unless the user specifies otherwise. Hold the
audience, message and sample content constant. Each candidate gets a name, its
seed, a short visual specification and a reason it suits this audience.
Distinguish candidates in at least 3 dimensions: composition, type hierarchy,
palette, image treatment or pacing. A colour swap is not a new direction.
Avoid a fixed catalogue of styles that would make every invocation look alike.

Render a small comparison using actual content:

- **Presentation:** an opening slide and a content-heavy slide for each concept.
- **Website:** the opening viewport and a representative interior section,
  with a narrow-screen view where relevant.

Show the previews together, using comparable dimensions. If rendering is
unavailable, label textual concepts as proposals and state what remains unseen.
Ask which elements to keep, change or reject, and why. Offer these controls in
ordinary language; no command syntax is required:

- **Reroll:** generate new seeds and new directions; retain the factual brief
  and all explicit dislikes.
- **Vary this:** keep named features, generate a new seed for the open design
  decisions, and record the parent concept.
- **Combine:** identify the specific parts to combine and resolve conflicts
  into one coherent system before making another preview.
- **Refine:** keep the chosen seed and design system; improve execution without
  restarting exploration.

When the user has delegated the choice, recommend and select a direction with
a short explanation. Otherwise, wait for their selection before expanding it.
Keep rejected previews and reasons so a reroll does not repeat the same mistake.

## Build around the content

For a presentation, outline each slide's point, supporting evidence, visual and
transition to the next point. Match the density to live delivery or independent
reading. For a website, outline the visitor's journey and primary action.
Preserve supplied facts and cite their sources; flag gaps instead of inventing
metrics, quotes, testimonials or customer logos.

Capture the chosen palette roles, font choices and fallbacks, type hierarchy,
spacing, composition rules, image treatment and motion behaviour in the brief.
Apply one identity across the artifact, with deliberate layout variation.
Do not reseed each slide or section. Check that the densest material fits this
system before expanding the rest.

Select assets for their role in the story. Use available image generation for
custom artwork when appropriate; preserve charts and important text as editable
elements. Generated video, transparent loops or transitions between stills are
optional, with static fallbacks and a stated playback purpose. Verify generated
media in context. Use configured tools; keep credentials out of the artifact.

Keep a compact record of seeds, visual specifications, prompts, asset paths,
source links and user choices in the project. Save the actual source and assets:
reusing a seed alone cannot reproduce the result.

## Review, revise and deliver

Read [the review guide](references/review.md). Capture the rendered artifact
and run up to 2 critique-and-fix rounds by default. This skill requests a fresh
design-critic subagent for each round when delegation is supported and permitted.
Give it the current renders, the audience and purpose, the chosen direction,
and any reference images. Omit implementation code, past scores and earlier
critiques. Keep the review rubric constant. Without subagents, perform the same
review yourself and identify it as self-review.

Fix the highest-impact observations first. A rating is supporting evidence,
not an instruction to keep spending until a number improves. Stop when the
brief is met and checks pass; after 2 rounds report remaining tradeoffs and
offer further refinement. Repair concrete functional or export defects before
calling the artifact finished. Remove elements that compete with the message.

Deliver the working artifact, requested exports and editable source. Include
a preview, how to open or present it, what was verified and any material limits.
Offer a focused next adjustment based on the result. Publishing, paid services,
commits and pushes follow the user's existing authorisation and working
agreements; invoking a design skill does not itself request those actions.

## Sources and scope

Inspired by Anshu Chimala's [How to turn your AI into a world-class designer](https://www.lennysnewsletter.com/p/how-to-turn-your-ai-into-a-world),
Lenny's Newsletter, 1 September 2026. The accessible text was checked on
15 October 2026 through technique 6; the body beginning at technique 7,
"Remove AI tells", was behind a paywall. This skill does not reconstruct it.

The original [String Seed of Thought research](https://pub.sakana.ai/ssot/)
uses model-generated strings. This workflow adopts the article's external
randomness variant. The interview, format-specific checks and iteration
controls here are an original adaptation for this skill, not quoted prompts.
