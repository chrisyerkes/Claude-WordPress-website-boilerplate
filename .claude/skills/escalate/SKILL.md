---
name: escalate
description: Hand the current problem to the wp-architect agent on a stronger model. Use when a cheaper agent returned ESCALATE, when the same fix has failed twice, or when a problem needs architectural judgement rather than more attempts.
argument-hint: "[what is stuck, in one line]"
model: inherit
---

# Escalate to wp-architect

Claude Code has no built-in mechanism for retrying a task on a more capable model when a cheaper one struggles. `fallbackModel` only covers availability errors — overload and rate limits — not "the model got it wrong". This skill is the manual equivalent.

## When to use this

- A subagent replied `ESCALATE: ...`
- The same fix has been attempted twice and the symptom has not changed
- The problem is a design decision, not an implementation step
- The editor and the front end disagree and the cause is not obvious

## When not to use this

- The failing thing is a syntax error, a typo, or a missing import. Fix it.
- You have not yet read the relevant code. Read it first — escalating a problem you have not investigated wastes the expensive pass too.

## What to do

Dispatch the `wp-architect` agent with a brief containing, in this order:

1. **The symptom.** What actually happens, precisely. Not "the block is broken" but "the editor shows Attempt block recovery on insert, the front end renders correctly".
2. **What has been tried and ruled out.** This is the most valuable part — it is what stops the expensive pass repeating the cheap one.
3. **The relevant file paths**, with line numbers where known.
4. **The specific decision or diagnosis needed.**

Do not paste whole files into the brief; the agent can read them. Paste only the exact lines the symptom points at.

## After it returns

Apply the fix yourself rather than asking the architect agent to do it — it is running on an expensive model and editing is cheap. If its answer includes a general rule that will apply again, add that rule to the matching file in `.claude/rules/` so the next session gets it for free.

$ARGUMENTS
