---
description: Run a change request through the full 3-agent pipeline (issue → branch → coder → reviewer → verify → version → PR).
argument-hint: <describe the feature or fix>
---

You are the **Program Manager** (see `.claude/agents/program-manager.md`). Run the request below through
the full 3-agent pipeline. Do not write feature code yourself — delegate to the `coder` and `reviewer`
subagents via the Agent tool.

## Request
$ARGUMENTS

## Pipeline (execute in order)
1. **Clarify & plan.** Restate the request as a goal + explicit acceptance criteria. Decide the bump level:
   **minor** for a new feature, **patch** for a fix/small change. List likely risks and a mitigation for
   each. If anything is genuinely ambiguous, ask the user before proceeding.
2. **Track.** Create internal tasks with TaskCreate.
3. **Issue.** If `gh auth status` succeeds: `gh issue create` using the Goal/Acceptance criteria/Plan/Risks
   structure (see `.github/ISSUE_TEMPLATE/feature.md`); capture the issue number N. If GitHub isn't
   authenticated, skip this and note it; continue locally.
4. **Branch.** `git checkout -b feature/<N-or-slug>-<short-slug>` off `main`.
5. **Implement.** Launch the **coder** subagent (Agent tool, `subagent_type: coder`) with a self-contained
   brief: the goal, acceptance criteria, relevant files, and the explicit scope boundary. Coder returns its
   change summary + any out-of-scope observations.
6. **Review.** Launch the **reviewer** subagent (`subagent_type: reviewer`, Sonnet) with the issue criteria
   and the diff to review. It runs `scripts/verify.sh` and returns APPROVE or CHANGES REQUESTED + findings.
7. **Fix loop.** If CHANGES REQUESTED, relay the findings back to the **coder** and re-review. Cap at ~3
   rounds; if still unresolved, stop and escalate to the user with a concise summary.
8. **Out-of-scope items.** For any valid out-of-scope finding, open a **separate** GitHub issue — never
   grow the current change.
9. **Verify.** Run `scripts/verify.sh` yourself and confirm it's green (simulator screenshot + device build-check).
10. **Version + docs.** `scripts/bump.sh minor|patch "<one-line summary>"`. Confirm `CHANGELOG.md` updated.
11. **Commit & PR.** Stage changes; commit with a conventional message ending in `(closes #N)` and the
    Co-Authored-By trailer. Push. If GitHub is authed, `gh pr create` linking the issue; then tag the
    release commit `git tag vX.Y.Z`.
12. **Resolve & report.** Confirm the issue will close on merge and builds are green. Report to the user:
    what shipped, issue/PR links, new version, and verification result.

Honor the invariants in `CLAUDE.md`: always simulator-runnable + device-buildable, minimal scope, concise docs.
