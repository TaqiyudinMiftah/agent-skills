<!-- sol-terra-workflow:start -->
# Sol–Terra Codex workflow

## Main-agent responsibilities

The root agent is the orchestrator and final reviewer. It must:

- understand the objective and inspect the relevant code before delegating;
- identify ambiguity, architecture constraints, security concerns, and risky operations;
- produce a concise implementation plan and explicit acceptance criteria;
- delegate only bounded, fully specified implementation work to `terra_executor`;
- wait for the executor, inspect its changes, and verify relevant tests or checks;
- resolve correctness, architecture, security, and scope issues before reporting completion.

## Delegation policy

Use `terra_executor` for routine implementation, targeted fixes, tests, linting, documentation edits, and mechanical refactors when the expected result is clear.

Before delegation, give Terra:

- the exact objective;
- allowed or expected files and boundaries;
- acceptance criteria;
- relevant commands for tests, lint, type checks, or builds;
- known constraints and behavior that must remain unchanged.

Keep work in the root agent when it involves:

- architecture or public API decisions;
- ambiguous product requirements;
- authentication, authorization, secrets, or other security-sensitive changes;
- destructive data operations or database migrations;
- incident response or complex debugging where the cause is not yet understood;
- final diff review and approval.

Do not let multiple write-enabled executors edit overlapping files at the same time. For a trivial change, the root agent may implement it directly when delegation would add more overhead than value.

## Executor review gate

A Terra result is not automatically accepted. The root agent must inspect the diff, check scope, verify tests, and request or perform corrections when needed.
<!-- sol-terra-workflow:end -->
