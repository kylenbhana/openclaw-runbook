# Skill Builder Prompt

This prompt helps you create or optimize AgentSkills following best practices.

## About AgentSkills

The [AgentSkills specification](https://agentskills.io/) provides a structure for creating maintainable, token-efficient skills. This prompt follows that model.

## Prompt Template

Copy and customize this prompt to have your agent create or refactor a skill:

```
I need help creating or optimizing an AgentSkill.

Skill name:
[your-skill-name]

Purpose:
What the skill does and when it should activate.

Triggers:
What kinds of tasks or questions should activate this skill.

Tools needed:
Any tools, commands, or APIs the skill will use.

Reference docs:
Docs or specs that should live in references/ for on-demand loading.

Existing skill (if applicable):
Path to the current SKILL.md if this is a refactor.

Please:
- Create or optimize the skill following AgentSkills best practices
- Keep the core workflow in SKILL.md and move details into references/
- Keep SKILL.md under ~500 lines
- Validate the structure using the AgentSkills validator
- Show the final file structure and contents
```

## Why Hard Constraints Matter

Vague instructions produce bloated, token-hungry skills every time. The hard constraint on line count (~500 lines) forces the agent to:

- Put core workflow in SKILL.md
- Move details into references/ for on-demand loading
- Keep token usage low
- Make the skill maintainable

Without constraints, you'll get a 2,000-line skill file that eats half your context window.

## Example Usage

**Creating a new skill:**

```
I need help creating an AgentSkill.

Skill name:
weather-checker

Purpose:
Check current weather and forecasts using wttr.in (no API key required).

Triggers:
Questions about weather, temperature, forecast.

Tools needed:
curl to fetch from wttr.in, parsing text output.

Reference docs:
wttr.in documentation should live in references/wttr-in-docs.md

Please:
- Create the skill following AgentSkills best practices
- Keep the core workflow in SKILL.md under ~500 lines
- Move API details into references/
- Show the final file structure and contents
```

**Refactoring an existing skill:**

```
I need help optimizing an AgentSkill.

Existing skill:
~/.openclaw/workspace/skills/my-bloated-skill/SKILL.md

Purpose:
The skill works but SKILL.md is 1,800 lines and burns too many tokens.

Please:
- Refactor following AgentSkills best practices
- Keep core workflow in SKILL.md under ~500 lines
- Move details into references/ for on-demand loading
- Validate the structure
- Show what changed
```

## Skill Structure

A well-structured skill looks like:

```
skills/
└── your-skill-name/
    ├── SKILL.md              # Core workflow (~500 lines max)
    ├── references/           # Loaded on-demand
    │   ├── api-docs.md
    │   └── examples.md
    └── scripts/              # Optional executables
        └── helper.sh
```

## Best Practices

**Keep SKILL.md focused:**
- Describe when to trigger
- Show the core workflow
- Reference details in references/

**Use references/ for:**
- API documentation
- Detailed examples
- Error handling tables
- Command syntax reference

**Test before deploying:**
- Run a test task
- Check token usage
- Verify it loads only what it needs

## Community Skills

Be cautious with third-party skills. A poorly written or malicious skill can cause real problems. Treat community skills as inspiration rather than drop-ins.

Building your own gives you:
- Full understanding of what it does
- Control over token usage
- No dependency on external maintainers
- Better debugging at 2am

## Security

Set basic rules in your workspace memory files:
- Never expose secrets or API keys
- Ask before external actions
- Verify before destructive operations

Not foolproof, but it helps as a guardrail.
