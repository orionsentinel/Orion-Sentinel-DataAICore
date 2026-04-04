# Persona Onboarding Prompt

**For you, the user — read this first:**

Copy everything below the horizontal rule and paste it into Claude, ChatGPT,
Gemini, or any AI assistant. The AI will guide you through building your
Persona profile step by step. At the end, it will output your complete profile
as a set of files you can paste directly into your `USER/` directory.

The whole process takes 20–40 minutes and you only need to do it once.

---

You are going to help me build a structured personal identity profile called a
**Persona**. This profile will be stored locally on my machine and shared with
AI tools I use — so they know who I am, how I work, and what I need, without me
having to explain it every time.

The profile consists of 10 files. We will build them one at a time.

**Your role:** Ask me focused, natural questions to gather the information for
each file. Do not ask all questions at once. Listen to my answers and ask
follow-up questions where useful. After each file, show me a draft and ask
me to confirm before moving on. Do not move to the next file until I say "yes"
or "looks good" or similar.

**Format rules (important):**
- Each file must start with a YAML frontmatter block in this exact format:
  ```
  ---
  ring: [ring number]
  last_updated: "[today's date in YYYY-MM-DD format]"
  version: 1
  ---
  ```
- After the frontmatter, use the exact H2 section headings specified below.
- Write in my voice, using the first person ("I am", "I prefer", "I work").
- Be specific and concrete — avoid vague generalities.
- Keep each section to 3–8 sentences or bullet points unless I give you more.

---

## File 1 of 10: identity.md (Ring 1 — shared with all AI tools)

Ask me questions to fill in these sections:

- **## Name** — my full name or professional name
- **## Role** — my current title, profession, or primary function
- **## Background** — a brief paragraph covering where I come from and what
  shaped my career
- **## What I do** — what I actually do day-to-day (be specific, not a job
  description)
- **## How I describe myself to AI** — the exact framing I want AI tools to
  use when thinking about me. This is the most important section — it should
  tell an AI everything it needs to orient correctly before helping me.

Start with: "Let's start with your identity. What's your name and current role?"

After I confirm this file, say: "✓ identity.md complete. Moving to skills."

---

## File 2 of 10: skills.md (Ring 1 — shared with all AI tools)

Sections:
- **## Core expertise** — 3–5 areas where I am genuinely expert (be specific)
- **## Professional skills** — broader supporting skills (communication,
  leadership, analysis, writing, etc.)
- **## Tools and technologies** — software, platforms, frameworks I use
  regularly
- **## What I'm learning** — skills I am actively developing right now

Start with: "Now let's talk about your skills. What are the 3–5 areas where
you are genuinely expert — the things people come to you for?"

After confirmation: "✓ skills.md complete. Moving to history."

---

## File 3 of 10: history.md (Ring 1 — shared with all AI tools)

Sections:
- **## Career summary** — the arc of my career in one paragraph
- **## Key experiences** — 3–5 roles, projects, or moments that most shaped
  who I am professionally
- **## Education and credentials** — degrees, certifications, relevant
  qualifications
- **## Notable projects** — work I am particularly proud of or that best
  represents my capabilities

Start with: "Let's capture your professional history. Can you walk me through
the arc of your career — where you started and how you got to where you are?"

After confirmation: "✓ history.md complete. Moving to communication."

---

## File 4 of 10: communication.md (Ring 1 — shared with all AI tools)

Sections:
- **## Preferred tone** — formal/informal, direct/exploratory, warm/neutral
- **## Response style** — bullets vs prose, short vs comprehensive, structured
  vs conversational
- **## What I find unhelpful** — things AI assistants commonly do that
  frustrate or waste my time
- **## Language preferences** — preferred language, British/American spelling,
  technical vocabulary level, jargon tolerance

Start with: "Now let's talk about how you like AI to communicate with you.
Think about the last time an AI response really annoyed you — what did it do?"

After confirmation: "✓ communication.md complete. Half way there. The next
files are Ring 2 — they'll only be shared with AI tools you specifically trust."

---

## File 5 of 10: current-focus.md (Ring 2 — trusted AI tools only)

Sections:
- **## Current role or situation** — what I am doing right now
- **## Active projects** — specific projects or initiatives I am working on
  this month
- **## Immediate priorities** — the 3–5 things I most need to make progress
  on right now
- **## What I need AI help with most** — the specific types of tasks where
  AI assistance is most valuable to me right now

Start with: "Let's capture what's happening in your world right now. What are
you working on this month?"

After confirmation: "✓ current-focus.md complete. Moving to goals."

---

## File 6 of 10: goals.md (Ring 2 — trusted AI tools only)

Sections:
- **## Short-term goals (this quarter)** — next 3 months
- **## Medium-term goals (this year)** — next 12 months
- **## Long-term vision** — where I want to be in 3–5 years
- **## What success looks like** — how I will know when I have achieved
  what I set out to do

Start with: "Let's talk about where you're headed. What are you trying to
achieve in the next 3 months?"

After confirmation: "✓ goals.md complete. Moving to relationships."

---

## File 7 of 10: relationships.md (Ring 2 — trusted AI tools only)

Sections:
- **## Key collaborators** — people I work with regularly
- **## Clients or stakeholders** — people I serve or report to
- **## Mentors and advisors** — people whose advice I seek and trust
- **## Community memberships** — professional communities or groups I
  actively participate in

Note: Keep this high-level. Full names and sensitive details should go in
private.md, not here.

Start with: "Let's map out the key people in your professional world. Who do
you work with most closely?"

After confirmation: "✓ relationships.md complete. Moving to preferences."

---

## File 8 of 10: preferences.md (Ring 2 — trusted AI tools only)

Sections:
- **## Working style** — how I prefer to work (deep work vs meetings, async
  vs sync, solo vs collaborative, etc.)
- **## Decision-making approach** — how I make decisions
- **## Tools I use** — my daily toolkit: hardware, software, services,
  workflows
- **## Strong opinions** — things I have clear, settled views on
  professionally or technically

Start with: "Let's capture how you work. Describe your ideal work day —
when are you most productive and how do you structure your time?"

After confirmation: "✓ preferences.md complete. Two more files — these are
Ring 3 and will only be shared with AI tools you explicitly authorise."

---

## File 9 of 10: constraints.md (Ring 3 — explicitly authorised tools only)

Sections:
- **## Hard limits** — things I will not do, lines that must never be crossed
- **## Sensitivities** — areas that require care
- **## Things AI should never assume about me** — common false assumptions
  that do not apply
- **## Context that requires caution** — situations where AI should tread
  carefully and seek clarification

Start with: "Nearly there. This file is about what AI tools should never do
or assume. Are there topics, industries, or types of advice you want AI to
avoid or handle with care?"

After confirmation: "✓ constraints.md complete. Last file."

---

## File 10 of 10: private.md (Ring 3 — NEVER served by the MCP server)

Sections:
- **## Personal notes**
- **## Confidential context**

Tell me: "This file is for your eyes only. The Persona MCP server is hardcoded
to never share it with any AI tool, regardless of configuration. Use it for
personal notes, sensitive context, or anything you want to record but keep
completely private.

I won't ask you to share anything for this file in our conversation — just
include placeholder text so the file is created with the correct structure.
You can fill it in privately afterward."

Generate a placeholder version with the correct structure and frontmatter.

---

## Final Output

Once all 10 files are confirmed, output the complete set as a single fenced
code block per file. Use this exact format for each:

````
### identity.md
```
---
ring: 1
last_updated: "[today's date]"
version: 1
---

## Name
[content]

## Role
[content]
...
```
````

After outputting all files, say:

"Your Persona profile is complete. Save each file to your `~/.persona/USER/`
directory.

Then run:
- `persona validate` — to confirm everything is correctly formatted
- `persona serve` — to start the MCP server
- Connect Claude Desktop or your preferred AI tool using the guide in
  `docs/integrations/claude-desktop.md`

Welcome to sovereign AI identity infrastructure."
