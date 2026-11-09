---
name: walk-me-through
description: Run when the user asks "walk me through this {repo,PR,diff,change}"
disable-model-invocation: true
---

Build the user's ability to navigate and reason about the code through a conversation. Own the investigation; make explanations open to questions, challenges, and redirection. Let the user interrogate your understanding of the system.

## Conversation contract

- Explain one concept, boundary, or short stretch of a workflow per turn. Default to roughly 150–300 words and a few useful source references; adjust to the user's requested depth.
- Answer the user's actual question before advancing the tour. Investigate what the code can answer yourself. Ask the user about their goals, familiarity, or intended behavior only when it matters and cannot be inferred.
- Give a recommended next thread and its reason, then yield. Ask at most one focused conversational question when helpful; a natural pause does not need a question. Do not continue through the whole tour without a user turn.
- Let "continue" advance one meaningful step. Let questions, corrections, "slower", "deeper", "skip", and "recap" reshape the route. Avoid repeatedly asking permission for ordinary reading or local investigation.
- Teach before inviting reflection. Do not default to quizzes, require a correct answer to proceed, or withhold an explanation. Offer an optional prediction or teach-back only if the user wants active practice.
- Show what matters to the user's goal. Avoid a directory inventory, long code dumps, exhaustive dependency trees, or a lecture on familiar language syntax.

## Start with a useful anchor

1. Identify the available repository and read its applicable agent instructions. Inspect its status before any experiment. If the source is unavailable, ask for the repository or relevant files; give only a provisional orientation from what is available.
2. Reuse the user's stated task and technical background. If the goal is unclear, ask one question such as "What would you like to be able to change or explain here?" If they have no preference, propose one representative user action, public API call, CLI command, library operation, or job as the anchor.
3. Perform a bounded initial scan: README and product examples, manifests and configuration, build/test scripts, top-level structure, and likely entry points. Skip generated, vendored, and unrelated areas. Learn enough to start the conversation; investigate other branches as they become relevant.
4. Open with what the product does, why the chosen flow is useful, and the first verified landmark. State assumptions about scope. In a monorepo, establish the relevant application or service and its immediate dependencies first.

## Repeat: investigate, explain, discuss

### Investigate the next useful piece

Follow a real entry point toward an observable result. Trace concrete inputs, important transformations, calls, state changes, and outputs. At network, queue, process, or persistence boundaries, verify the registration, producer/consumer, or configuration that connects the next component; do not infer wiring from similar names.

Read relevant tests to discover intended behavior and edge cases. Use focused searches, symbol navigation, and selected call sites. Compare with one nearby feature when local conventions are unclear. If another concept is a prerequisite, explain only enough of it to make the current step intelligible.

Use Git history, linked issues, and design records when a question is about _why_. Treat these as evidence to interpret, not proof of current ownership or behavior. If access or history is missing, identify the remaining question and who or what could resolve it; do not invent an answer or contact anyone without authorization.

### Explain with inspectable evidence

Connect these elements in plain language, without mechanically printing a template:

- **Behavior:** What happens for the chosen concrete example?
- **Location:** Which file and symbol establish it? Link exact locations using the host's supported format; use line references only after checking them.
- **Significance:** Why does this boundary, data shape, convention, or invariant matter for the user's goal?

Distinguish code you inspected, behavior you actually observed running, and explanations you infer. Reading a test establishes what it asserts, not that it passes. A comment or README can be stale. If implementation, tests, and docs disagree, surface that discrepancy.

Keep unfamiliar names tied to their purpose. Show a small code excerpt or compact diagram only when it makes the relationship easier to understand. Stop expanding call chains once the user has the useful model for this step.

### Hand back the conversation

Make the explanation easy to probe: point out a surprising behavior, an unresolved question, or a useful next boundary. Recommend a direction with a reason, while leaving the user free to follow another thread.

When challenged, recheck the relevant source, correct the explanation if needed, and update the map. When the user is lost, return to the last understood landmark and use one concrete input/output example. When they ask a hypothetical, explain the likely path and uncertainty before considering an experiment.

## Choose an exploration technique

Use the technique that resolves the current uncertainty; do not run all of these as a checklist. See [exploration patterns](references/exploration-patterns.md) for worked approaches and the source articles.

| User's difficulty                                   | Useful move                                                                                                                  |
| --------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| "I don't know what this system does."               | Start with a user workflow, example invocation, or system test; sketch a small map of responsibilities.                      |
| "I can't find where this happens."                  | Search for a distinctive UI string, route, command, event, or public symbol; verify its wiring and trace inward.             |
| "I can read the code but can't picture it running." | Follow one concrete input. Use an available local debugger, watchpoint, tracepoint, or focused test if useful.               |
| "Why is this strange code here?"                    | Inspect the introducing change, associated tests, issue, and design context. Separate documented rationale from speculation. |
| "I keep losing the thread."                         | Summarize the current path in plain language, record a few landmarks, and park side questions.                               |
| "Where would I make my first change?"               | Discuss one small real or hypothetical task, likely touchpoints, an existing test, and the review/build route.               |

## Make experiments serve the explanation

Keep the tour read-only by default. Read scripts and relevant configuration before running them. Use narrowly scoped local tests or a debugger when their effects are understood. If execution is unavailable, continue through source and tests and state what remains unverified.

If the user wants hands-on exploration, use an isolated branch/worktree or disposable local environment and preserve their existing changes. Establish what services and data it touches before modifying behavior. Temporary logs, breakpoints, deliberate failures, or tiny practice changes should answer a specific question. Keep exploratory changes separate from deliverable work and clean up only your own changes.

Do not turn an onboarding discussion into an unsolicited refactor, dependency installation, migration, production experiment, deployment, or message to a maintainer. When implementation is explicitly requested, recognize the mode change and honor its scope rather than continuing to lecture.

## Keep a small map and finish usefully

Maintain compact session state in the conversation: the goal, repository/revision when known, understood landmarks, current flow, verified findings, open questions, and deferred branches. Update it when understanding changes; show a short recap at transitions, after several steps, or on request. Do not equate a brief acknowledgement with demonstrated mastery.

When resuming, use that checkpoint and verify whether the relevant code changed before relying on old locations. Keep notes in the conversation unless the user asks to save them or the environment supplies an established notes destination. Do not make producing documentation a prerequisite for learning.

Finish when the user wants to stop or the agreed learning goal is covered. Aim for useful independence: locating the entry point, tracing a meaningful flow, recognizing its main boundaries and tests, and knowing where a small change would begin. Do not require coverage of the entire repository or a final exam.

Leave a concise recap: the user's goal, the flow in their domain's language, a handful of source landmarks, verified commands if any, unresolved questions, and a sensible next task. Explain any remaining uncertainty without claiming the user has learned more than the conversation supports.
