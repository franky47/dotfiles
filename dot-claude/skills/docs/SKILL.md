---
name: docs
description: Use when writing, editing, or organizing documentation, when planning what docs a feature needs, and whenever planning or implementing a new feature or change in a repo (docs ship with the code). Triggers on "write docs for X", "document this feature", "add a guide", "update the docs", "reorganize the docs", "plan feature X", "implement X", or /docs.
metadata:
  author: https://github.com/AlemTuzlak/skills/blob/main/skills/docs/SKILL.md
---

# docs

Write docs a real person wants to read. Short, plain, built around someone trying to do a real thing.

"Document feature X" is not the job. "Help someone do Y with X" is the job.

Work in two phases. First plan the story: who reads this, what they want, and how many pages it should be. Then write.

## When to run

Docs ship with the code. Run this skill at three moments, not only when asked.

- Someone asks for docs. Write them.
- Planning a feature or change in a repo. Before the plan is done, list which docs are new and which need updating. This doc-impact list is part of the plan, the same as the code changes.
- Finishing an implementation. Write or update those docs before you call the work done. A change to how something behaves that ships no doc change is not finished.

## Find the docs first

Before writing anything, find where docs live.

1. Look for a docs folder. Check `docs/` first, then `packages/docs`.
2. Found nothing? Ask the user where docs should go. Do not guess and do not create a folder on a hunch.
3. Open 2 or 3 existing pages near where the new content belongs. Read them for voice, tone, frontmatter fields, and structure.
4. Note which components the site already uses (steps, tabs, callouts, cards, accordions, code groups, and so on). Different sites have different ones.
5. Reuse those components to tell the story. If the site has a steps component, use it for walkthroughs. If it has tabs, use them for framework variations. If the site has none, use plain markdown. Never invent a component the site does not have.

If there is no page like the one you are about to write, read the closest one you can find and match it.

## Phase 1: plan the story

Do this before you write a word of content.

1. List who reads this and what each one wants. A person building on a React SPA, a person on a server-rendered app, someone who just wants a quick demo, someone extending the internals. Do not stop at the first reader.
2. Write one user story per reader: "As a X, I want to Y, so I can Z."
3. Turn stories into pages. One journey is one page. Different journeys are different pages. A feature with three real journeys is three pages plus maybe a short overview, not one giant page.
4. Check every reader has a path. A reader with no page is a hole in the plan. Add a page or a route for them.

The page split comes out of this step. Do not skip it.

## Less is more: split, do not cram

Do not force thousands of words into one page. Long pages hide the answer.

When a topic has several angles, give each its own short page and link them. A reader lands on the overview, then clicks into the exact thing they need.

Example. A feature for tool interrupts:

```
Bad: one page
  interrupts.md   (overview + simple case + many interrupts + custom, all crammed in)

Good: a small set of linked pages
  interrupts/index.md            what it is, when to use it, links out
  interrupts/basic.md            one interrupt, start to finish
  interrupts/multiple.md         several interrupts in a flow
  interrupts/custom.md           build your own
```

Each page is short and does one thing. The overview stitches them into a story.

## Phase 2: write like a human

Legibility is the goal, above everything else. Use the `no-ai-slop` and `prose` skills for content guidance.

- Keep it digestible. No walls of text, no huge paragraphs. Break ideas into small pieces. Give the smallest amount of info that does the job.
- Use simple English. Assume the reader speaks B1 to B2 English. Skip big, heavy words when a plain one works. "use" not "utilize", "start" not "commence", "about" not "regarding".
- Keep markdown light. Lists are fine. Bold headings on every line are not. Let the words carry the page.
- Prefer plain ASCII and normal keyboard characters over fancy glyphs. Write the way a person types.
- Second person, action first. Start with what the reader has now and what they will have at the end. No "In this guide we will explore..." openings. Just start.

### Lead with the problem, then solve it

Every page opens with the problem the reader came for, in their own words, before any API. Name the situation they are stuck in. Then say in a sentence or two how the feature solves it. Only after that do you go into the technical parts and the code.

A reader who sees the problem first knows in seconds whether they are on the right page. A reader who hits an API signature first has to reverse-engineer what it is even for.

```
Bad:
  Call useInterrupts() and pass a resolver. The resolver runs once per
  pending item inside a transaction...

Good:
  Some tool calls shouldn't run without a human saying yes: moving money,
  deleting data. An interrupt pauses the run for that decision, then picks up
  where it left off. Here is how to gate a tool behind an approval:

  [code]
```

The order for a guide is problem, one-line fix, then the how (steps, snippets, API). Keep the problem to a couple of sentences, not a background essay. The code shows how it is solved, so do not narrate the solution in prose first.

### Show, do not tell

Do not explain in four paragraphs what one sentence and a code block can show. Readers grasp a diff or a snippet faster than prose.

```
Bad:
  Three paragraphs describing how the config object accepts a
  middleware array, what each slot does, and how ordering works.

Good:
  Add your middleware to the `middleware` array. Order runs top to bottom:

  const app = createApp({
    middleware: [auth, logging],
  })
```

One good runnable example beats a page of description. Every code sample must run when copied, not need imagination to fill gaps.

### Page shape for a guide

Problem, fix, steps, done.

- Open with the problem the reader has, in their words, and what they will have at the end.
- Say in a sentence how the feature solves it.
- Walk through steps they can follow and test as they go, with the code doing the explaining.
- End when they reach the goal. Do not close with a vague "next steps" dump.

Reference pages (props, types, signatures) stay scannable and link back to the guide that shows them in use.

## Write for the reader, not the history

Docs describe what exists now. The reader never saw the old design, the earlier name, the draft PR, or the API you replaced along the way. Do not make them read about it.

Never justify the current API by comparing it to a version that did not ship. A line like "instead of `useAssistant`, this uses `usePlugin`, which makes more sense because..." is noise to someone who never knew `useAssistant` existed. Cut it and just describe `usePlugin`.

```
Bad:
  We renamed useAssistant to usePlugin and moved the tools onto it,
  so instead of calling assistant.addTool you now use plugin.tools.

Good:
  Register tools on the plugin with plugin.tools:

  const plugin = usePlugin({ tools: [search] })
```

Ban this framing from the output: "instead of X", "we renamed", "previously called", "this replaces the old", "unlike the earlier", and any transitional name that never reached a release.

The one exception is a real migration. If users had X in a shipped, public release and you are moving them to Y, a short "Migrating from X" note is worth writing, because those readers actually used X. A name that only lived in a branch or a draft is not that. When unsure whether an old name shipped, leave it out.

## Forbidden

Never use these. Ever.

- Em dashes and en dashes: the long `—` and the shorter `–`. Rewrite the sentence with a comma, colon, period, or parentheses instead.
- Separator glyphs like `×` or `·`.
- The pattern "It's not X: it's Y." and the "Not just X, but Y" three-part build-up.
- The phrases "key insight", "gap", and variations of them.

If you catch yourself reaching for one of these, stop and rewrite the sentence in plain words.

## Cross-linking and placement

- Put new pages where they fit the reader's path, grouped by what the reader is doing ("Building with React"), not by code layer ("Frontend Package API"). Update the site's nav or index so the page is reachable. An orphan page does not ship.
- Link related pages at the moment they help, inline in the flow, not as a "Related" dump at the bottom.
- Cross-linking goes both ways. When you add a page, update the older pages that should point into it.
- Do not over-link. One well-placed "need X? see Y" beats a list of maybes.

## Red flags

| You catch yourself                                         | Do instead                                                                   |
| ---------------------------------------------------------- | ---------------------------------------------------------------------------- |
| Opening with an API signature or config before the problem | Name the problem the reader has first, then the one-line fix, then the code. |
| Writing three paragraphs before any code                   | Cut to one sentence plus a snippet. Show it.                                 |
| Cramming every angle into one page                         | Split into short linked pages, one job each.                                 |
| "In this guide we will explore..."                         | Delete it. Start with the reader's state and goal.                           |
| "Let me describe what this component does"                 | Describe what the reader does with it.                                       |
| Reaching for an em dash                                    | Rewrite with a comma, period, or parentheses.                                |
| Using a big word (utilize, leverage, facilitate)           | Swap in the plain word.                                                      |
| One page for everyone                                      | Name the readers. Give each a path or a page.                                |
| Posting a snippet "they can adapt"                         | Make it complete and runnable.                                               |
| Guessing where docs go                                     | Find the docs folder, or ask. Read neighbors first.                          |
| Calling a feature done with no doc change                  | If behavior changed, docs change too. Write them before you finish.          |
| Planning a feature without a doc-impact list               | Add the list of new and changed docs to the plan.                            |
| "Unlike the old X, this now..." / "we renamed X to Y"      | The reader never saw X. Describe only what ships now.                        |
| Inventing a component the site lacks                       | Use only components the site already has.                                    |
