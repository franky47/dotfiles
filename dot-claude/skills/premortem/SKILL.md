---
name: premortem
description: "Run a premortem on any plan, launch, product, hire, strategy, or decision. Assumes it already failed 6 months from now and works backward to find every reason why. Produces a revised plan with blind spots exposed. MANDATORY TRIGGERS: 'premortem this', 'premortem my', 'run a premortem', 'what could kill this', 'future-proof this', 'stress test this plan', 'what am i missing here', 'find the blind spots'. STRONG TRIGGERS: 'what could go wrong', 'am i missing anything', 'poke holes in this', 'where will this break', 'devil's advocate this'. Do NOT trigger on simple feedback requests, or factual questions. DO trigger when someone has a plan or commitment where the cost of being wrong is high."
user-invocable: true
---

# Premortem

A premortem is the opposite of a postmortem. Instead of figuring out what went wrong after something fails, you imagine it already failed and figure out why before you start.

The method comes from psychologist Gary Klein. He published it in Harvard Business Review. Daniel Kahneman (the Nobel Prize-winning psychologist behind "Thinking, Fast and Slow") called it his single most valuable decision-making technique. Google, Goldman Sachs, and Procter & Gamble all use it before major decisions.

The core insight: when you ask people "what could go wrong?" they give you cautious, hedged answers. When you say "this already failed, tell me why," their brains switch into narrative mode and generate way more specific, creative, honest reasons. Researchers at Wharton and Cornell called this "prospective hindsight" and found it significantly increases the ability to identify causes of future outcomes.

The reason this matters for AI-assisted decisions: Claude defaults to agreeable, optimistic responses. If you ask "is this a good plan?" it will find reasons to say yes. The premortem breaks this pattern by forcing the frame into "this is dead, explain how it died." Claude stops looking for reasons your plan will work and starts explaining how it fell apart.

---

## when to run a premortem

Good premortem targets:

- A product or feature you're about to build
- A launch plan with money or reputation on the line
- A pricing change or business model shift
- A hire you're about to make
- A strategy or positioning pivot
- A partnership or deal you're evaluating
- Any commitment where the cost of being wrong is high

Bad premortem targets:

- Vague ideas with no concrete plan yet (help them plan first, then premortem)
- Questions with one right answer (just answer them)
- Requests for creative feedback on a draft (that's editing, not a premortem)
- Decisions that are already made and irreversible (a premortem is only useful when you can still change course)

---

## context gathering (the minimum bar)

A premortem is only as good as the context it runs on. Vague input produces vague failure scenarios that help nobody. Before running the premortem, you need to hit a minimum context threshold.

### step 1: scan for existing context

Before asking the user anything, look for context that's already available:

**A. The current conversation.** The user may have been discussing a plan, a launch, a product, or a decision earlier in this session. Read back through the conversation and extract whatever's relevant.

**B. The workspace.** Quickly scan for files that might contain relevant context:

- `CLAUDE.md` or `claude.md` (business context, preferences, constraints)
- Any `memory/` folder (audience profiles, business details, past decisions)
- Files the user explicitly referenced or attached
- Any project files, briefs, or plans that relate to the thing being premortemed

Use `Glob` and quick `Read` calls. You're looking for the key files that would ground the failure scenarios in reality.

### step 2: evaluate context sufficiency

After scanning, check whether you have enough to run a useful premortem. You need three things:

1. **What is it?** — A clear understanding of the thing being premortemed (a product, a launch, a hire, a pricing change, a strategy). You need to be able to describe it back to the user in one sentence.

2. **Who is it for / who does it affect?** — The audience, the customer, the team, the stakeholders. Failure scenarios depend heavily on who's involved.

3. **What does success look like?** — What outcome is the user hoping for? Failure is defined by inverting success. If you don't know what success means, you can't define what failure means.

### step 3: fill gaps conversationally

If you have all three, proceed immediately to the premortem. Don't ask unnecessary questions.

If you're missing one or more, ask for the most important missing piece first. One question at a time. Evaluate after each answer whether you now have enough. Keep asking until the threshold is met, but never ask more than you need.

Examples of focused context questions:

- "What specifically are you about to launch/build/decide?" (if you don't know what it is)
- "Who is this for?" (if you know the plan but not the audience)
- "What does a win look like for this?" (if you know the plan and audience but not the success criteria)

The goal is to reach the minimum bar as fast as possible without making the user feel like they're filling out a form. Conversational, not interrogative. If you can infer an answer from context, do that instead of asking.

---

## how a premortem session works

### step 1: set the frame

After gathering sufficient context, set the premortem frame explicitly. Something like:

"OK, I have enough context. Let's run the premortem. Here's the premise: it's 6 months from now. [The plan/launch/decision] has failed. It's done. We're looking back and trying to understand what went wrong."

This framing matters. It shifts the mode from "evaluate this plan" (which triggers agreeable responses) to "explain why this died" (which triggers honest, specific failure identification).

### step 2: generate failure reasons (raw premortem)

Run the raw premortem as a single comprehensive analysis. No prescribed categories, no lenses, no constraints. Just the core Klein method:

"This plan has failed 6 months from now. Generate every genuine reason it could have died. Be comprehensive. Be specific. Ground every reason in the actual details of the plan. Don't pad with weak reasons and don't stop early if there are more."

The output should be a comprehensive list of failure reasons, each stated in 1-2 sentences. Be honest and thorough. Some plans might have 4 genuine failure modes. Others might have 9. The number should be whatever is real for this specific plan.

Each failure reason should be:

- Specific to this plan (not generic advice that applies to anything)
- Grounded in actual details the user provided
- A genuine threat (not a minor inconvenience or an extremely unlikely edge case)

### step 3: deep-dive agents (one per failure reason, all in parallel)

Take every failure reason from step 2 and spawn one sub-agent per reason, all in parallel. Each agent takes its assigned failure reason and goes deep on it independently.

**Sub-agent prompt template:**

```
You are an investigator in a premortem analysis. You've been assigned one specific failure reason to analyze in depth.

The plan:
---
[full context: what it is, who it's for, what success looks like, plus relevant workspace context]
---

PREMORTEM FRAME: It is 6 months from now. This plan has failed.

YOUR ASSIGNED FAILURE REASON: [the specific failure reason from step 2]

Your job is to go deep on this one failure. Write the story of how it actually played out. Be specific. Use details from the plan. Make it feel real, like a case study of something that actually happened.

Your output should include:

1. THE FAILURE STORY: A 2-3 paragraph narrative of how this specific failure played out. Use details from the plan. Name specific moments where things went wrong and why.

2. THE UNDERLYING ASSUMPTION: The one thing the user was taking for granted that made this failure possible. State it in one sentence.

3. EARLY WARNING SIGNS: 1-2 concrete, observable signals the user could watch for that would indicate this failure mode is starting to play out. These should be things you can actually see or measure, not vague feelings.

Keep the total response under 300 words. Be direct. Don't hedge. Don't sugarcoat.
```

### step 4: synthesis

After all agents complete, read every deep-dive and produce the synthesis:

**PREMORTEM REPORT**

1. **The Most Likely Failure** — Which failure scenario is most probable given what you know about the plan? Why? This is the one the user should focus on first.

2. **The Most Dangerous Failure** — Which failure scenario would cause the most damage if it happened, even if it's less likely? This is the one worth insuring against.

3. **The Hidden Assumption** — Across all the failure analyses, what's the single biggest assumption the user is making that they probably haven't questioned? This is often where the real value of the premortem lives: the thing that's so obvious to the user that they forgot it was an assumption.

4. **The Revised Plan** — Based on the failure scenarios, what specific changes would make the plan more resilient? Be concrete. Don't say "consider your pricing." Say "test pricing at $X with 20 people before committing to it publicly." Each revision should map directly to a specific failure scenario.

5. **The Pre-Launch Checklist** — 3-5 specific things the user should verify, test, or put in place before executing. Each one should prevent or detect one of the failure modes identified.

### step 5: generate the premortem report

Generate a visual HTML report and save it to the user's workspace.

**File:** `premortem-report-[timestamp].html`

The report should be a single self-contained HTML file with inline CSS. Design principles:

- Dark background (#0a0e1a or similar), clean typography, easy to scan
- The synthesis section (most likely failure, most dangerous failure, hidden assumption, revised plan, checklist) should be prominently displayed at the top since that's what most people will read first
- One visual card per failure reason showing the deep-dive analysis. Each card should display the failure reason as a header, the failure story, the underlying assumption, and the early warning signs. Use distinct accent colors for each card so they're visually scannable.
- A clear visual indicator of severity/likelihood for each failure mode
- The round-robin visual: show the number of agents that ran and their findings as a grid or card layout, so the user can see the full scope of the premortem at a glance
- Footer with timestamp and what was premortemed

Open the HTML file after generating it.

### step 6: save the transcript

Save the full premortem transcript as `premortem-transcript-[timestamp].md` in the same location. This includes:

- The context that was gathered (what, who, success criteria)
- The raw premortem failure reasons
- All agent deep-dives
- The full synthesis

---

## output format

Every premortem session produces two files:

```
premortem-report-[timestamp].html    # visual report for scanning
premortem-transcript-[timestamp].md  # full transcript for reference
```

The user sees the HTML report first. The transcript is there if they want to dig deeper into the reasoning behind each failure scenario.

Also provide a concise summary in the chat: the most likely failure, the hidden assumption, and the single most important revision to the plan. Three sentences max. The report has the full details.

---

## example: premortming a product launch

**User:** "premortem this: I'm about to launch a $297 live workshop on how to use Claude Cowork for marketing teams. 50 seats. Targeting marketing managers at companies with 10-50 employees."

**Raw premortem identifies 6 failure reasons:**

1. Marketing managers at this company size need approval to spend $297 on professional development, adding friction you haven't accounted for
2. "Claude Cowork for marketing" is a tool-specific pitch in a market where most managers are still figuring out whether AI is relevant to them at all
3. The audience that actually buys might be solopreneurs, not team managers, creating a mismatch between content and attendees
4. Building a workshop for marketing teams requires demo environments with realistic marketing data and multi-seat setups, which takes 5 weeks of prep, not the 2 you budgeted
5. If 60% of attendees are solopreneurs, your reviews and case studies won't resonate with the marketing manager audience you need for future cohorts
6. At $297 with 50 seats, the max revenue is $14,850, which may not justify the prep time against other revenue opportunities

**6 agents go deep on each reason independently, producing failure stories, underlying assumptions, and early warning signs.**

**Synthesis:** Most likely failure is the audience mismatch: you're targeting people who need approval to spend $297, which adds friction you haven't accounted for. Most dangerous failure: attracting solopreneurs instead of team managers means your case studies and testimonials won't resonate with the actual target buyer for future cohorts, compounding the problem over time. Hidden assumption: you're assuming "marketing managers at 10-50 person companies" is a reachable audience, but these people don't self-identify that way and don't hang out in the same places. Revised plan: run a $47 pilot session for 20 people first. Use that to identify whether your actual buyers are team managers or solopreneurs, and build the full workshop for whoever actually shows up.

---

## important notes

- **Always spawn all failure agents in parallel.** Sequential spawning wastes time and lets earlier responses influence later ones.
- **Always set the premortem frame explicitly.** "This has already failed" is the psychological mechanism that makes this work. Without it, the analysis defaults to polite risk assessment instead of honest failure identification.
- **Be comprehensive but not padded.** Find every genuine failure reason. Don't stop at 3 if there are 7. But don't force 7 if there are only 3. The number should be whatever is real for this specific plan.
- **The synthesis is the product.** Most users will read the synthesis and skim the individual failure cards. Make the synthesis specific and actionable.
- **Don't sugarcoat.** The whole point of a premortem is to tell the user things they don't want to hear before reality does. If a plan has serious problems, say so directly.
- **The revised plan must be concrete.** Don't say "consider testing your pricing." Say "run a $47 pilot with 20 people before committing to the full $297 workshop." Every revision should be something the user can actually do this week.
- **Respect the minimum context threshold.** Running a premortem on insufficient context produces generic failures that waste the user's time. It's better to ask one more question than to produce a bad premortem.
- **This is not the LLM Council.** The council gives multiple perspectives on a decision right now. The premortem sends Claude into the future where the decision already failed and works backward to explain why. Different psychological mechanism, different output. If the user seems to want multiple perspectives rather than failure analysis, suggest the council instead.
