# Review the rendered result

Inspect the artifact at its actual delivery size. Code, slide object geometry
and a successful export are insufficient evidence of visual quality. Include
the densest content, long headings, charts, media and the ending in the review.

## Critic brief

Use the same request for each fresh review. Supply current renders, the audience
and purpose, the chosen visual specification and optional visual references.
The reviewer does not need implementation history.

> Review whether this artifact serves the stated audience and purpose. Identify
> its strongest design decision, then the 3 most consequential visible problems.
> For each problem, name the slide, section or region, explain its effect on
> the audience and suggest a concrete correction. Evaluate message hierarchy,
> readability, composition, consistency and fit to the intended identity.
> Treat reference images as evidence of desired qualities, not templates to copy.
> Give an overall score out of 10 with a brief justification. State what cannot
> be judged from these images. Do not infer interaction or factual correctness
> from appearance alone.

A score is subjective. Preserve the useful observations even when two scores
disagree. Do not include a desired score in the critic's request or keep
repeating the loop solely to improve it. The implementer owns the checks below.

## Every artifact

- [ ] The opening makes the subject and purpose clear; the ending supports the
  requested action or takeaway.
- [ ] Each slide or section has an obvious reading order and focal point.
  Decoration supports the content and does not obscure it.
- [ ] Text fits without clipping, accidental overlaps, cramped lines or tiny
  captions. Alignment and spacing remain consistent across the whole artifact.
- [ ] Font files or fallbacks work in the destination. Titles and body text
  remain legible at realistic viewing distance, not just when zoomed in.
- [ ] Colour contrast and non-colour cues support readability. Check contrast
  where tools allow; do not claim accessibility conformance from screenshots.
- [ ] Images are sharp enough, appropriately cropped and visually coherent.
  Check generated assets for malformed text and distracting defects.
- [ ] Quotes, claims and numbers match their sources. Charts show the necessary
  units, dates, labels and honest comparisons. Required citations are present.
- [ ] No placeholders, sample metrics, broken assets or accidental process notes
  remain. Seeds and critique logs are absent from the audience-facing artifact.
- [ ] Motion has a readable static alternative. Essential content never depends
  on sound, hover or animation alone.
- [ ] Remove repeated explanations, competing emphasis and unnecessary framing.
  Retain any element that serves a clear navigational or explanatory purpose.

## Presentation checks

- [ ] Review a contact sheet for narrative order, rhythm, repeated layouts and
  identity drift; inspect every slide individually for fitting problems.
- [ ] Claims and charts are readable at presentation size. Supporting detail
  moves to notes or an appendix when it would overwhelm live delivery.
- [ ] Notes and slide numbers are correct, and intentional reveals work in the
  target application. Timing fits the agreed talk length.
- [ ] Reopen or render the final exported file. Check substituted fonts,
  flattened charts, media playback, transparency and missing elements.
- [ ] If a PDF or handout is requested, check that static pages communicate the
  intended meaning without relying on earlier animation frames.
- [ ] For browser slides, exercise forward and backward navigation, keyboard
  focus, fullscreen and narrow screens as applicable. Check the requested print
  and offline paths rather than assuming they work.
- [ ] Confirm which elements remain editable and disclose any format conversion
  limits. A collection of slide screenshots is not an editable deck.

## Website checks

- [ ] Inspect wide and narrow layouts, including long content and intermediate
  widths that could expose wrapping or overflow problems.
- [ ] Exercise navigation, primary actions, forms and relevant interaction
  states. Distinguish working integrations from demonstration behaviour.
- [ ] Check headings, keyboard navigation, visible focus, image descriptions
  and form labels with appropriate inspection tools.
- [ ] Exercise reduced motion and inspect static fallbacks. Media does not block
  reading or interaction; start, middle and end states all work visually.
- [ ] Inspect console errors, missing assets and obvious loading problems using
  the available development or browser tools. Run applicable project checks.
- [ ] Inspect the deployed version if deployment was requested and completed.
  Otherwise deliver a working local or preview version with clear instructions.

## Finish with evidence

Default to 2 review rounds. Track the top findings, changes made and outstanding
tradeoffs in the project brief. Do not call a check passed if it was not run.
If a required render, target application or export cannot be inspected, state
that limit in the handover and identify the practical consequence.

Link the final artifact and requested exports, show a representative preview,
and say how to open, present and edit it. Keep the handover short enough that
the user can act on it immediately.
