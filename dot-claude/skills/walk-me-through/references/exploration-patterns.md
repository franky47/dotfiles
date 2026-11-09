# Exploration patterns and sources

Read a relevant pattern when deciding how to investigate or explain the next step. Treat these as alternatives to combine selectively. The onboarding articles below were published before 2023; the interaction inspiration is separate. The skill is self-contained and does not require fetching these pages during an ordinary tour.

## Start with product behavior, then connect the structure

Use a recognizable operation to give names and folders meaning. Inspect configuration to identify build commands, supported environments, dependencies, and boundaries. Read a system test to see an intended journey. Sketch a few responsibilities, then trace one workflow. Repeat until navigation becomes predictable; do not try to memorize every file.

Source: Jesse Hill, [6 Steps to Understanding a Large, Legacy Codebase](https://spin.atomicobject.com/understand-legacy-codebase/), 21 July 2020. Hill explicitly draws on several legacy codebases.

## Learn through one real problem

When the overview remains abstract, investigate a scoped bug or feature. Establish expected and actual behavior, then follow relevant logs, stack traces, and source. Notice missing access or documentation along the way. Explain one flow before widening the map.

Source: Jonas Meinerz, [Getting Up and Running Quickly When Joining a Project](https://thoughtbot.com/blog/getting-up-and-running-quickly), 31 January 2022. Meinerz draws on multiple project transitions and prefers focused problem solving to initial architecture tours.

## Follow execution and state

Use a debugger to investigate a specific uncertainty: a watchpoint for who mutates a value, return-value inspection for a transformation, or an object marker/conditional breakpoint for one instance's path. Tracepoints can show a flow without repeatedly stopping it. If the tool or runtime is unavailable, inspect the equivalent code and clearly qualify the conclusion.

Source: Shai Almog, [Understand Source Code — Diving Deep into the Code Base, Locally and in Production](https://medium.com/better-programming/understand-source-code-diving-deep-into-the-codebase-locally-and-in-production-cba8a6732460), 22 June 2022. Almog describes more than a decade of consulting with frequent new projects. Adapt the debugging method without requiring the vendor-specific production tooling.

## Verify one path through the stack

For a web feature, trace the visible action through its handler, client call, server registration, business operation, persistence or job, and observable result—only as far as the actual system goes. Verify each cross-process connection. Use isolated experiments to test surprising links; keep exploration out of the real change.

Source: Daniel Hugenroth, [Stack diving: getting up to speed in a large codebase](https://www.danielhugenroth.com/posts/2022_08_stack_diving/), 26 August 2022. The post draws on onboarding in larger organizations and mentoring engineers.

## Reconstruct history without inventing intent

Inspect a confusing change's diff and message, related tests, linked PR/issue, and nearby follow-up fixes. Explain what these sources establish. Use past contributors as leads for locating knowledge, not as guaranteed current owners. Preserve uncertainty when the rationale is missing.

Sources: Filip Danić, [How to Master a New Codebase](https://danicfilip.com/2017/how-to-read-and-navigate-new-codebase/), 6 August 2017, updated 1 November 2020; RoyalSloth, [On navigating a large codebase](https://blog.royalsloth.eu/posts/on-navigating-a-large-codebase/), 1 November 2020. Both explicitly describe experience across multiple projects; RoyalSloth discusses million-line systems.

## Turn reading into a model

Summarize behavior in plain language while proceeding mostly breadth-first. Keep important entry points and responsibilities, not a transcript of every line. Track questions separately. Offer the user the chance to rephrase a flow if they want practice, but never make that a gate or substitute for your explanation.

Source: David Golden, [A better way to learn a new codebase](https://xdg.me/learn-a-new-codebase/), May 2021. Golden describes outlining code to check and retain his understanding when joining teams.

## Build confidence with a tiny change

Discuss a small hypothetical or real task near the chosen workflow. Predict where it belongs and what behavior or test would show success. If hands-on work is desired, use a disposable practice change before taking a real task through the delivery process. Read recent tickets and PRs to understand local conventions.

Source: Keegan Donley, [Tips for Onboarding Onto an Existing Codebase](https://keegan.codes/blog/tips-for-onboarding-onto-an-existing-codebase), 18 January 2022. Donley describes methods used in company, freelance, and open-source contexts.

## Interaction inspiration

Borrow adaptive branching and agent-owned factual investigation from Matt Pocock's [description of /grill-me](https://www.aihero.dev/my-grill-me-skill-has-gone-viral) (2026). Reverse the explanatory burden: investigate and present an inspectable model for the user to question. Choose one conversational step at a time for this skill; do not assume that every version of /grill-me uses that pacing.
