---
name: brainstorm
description: >
  Brainstorm new project ideas, features for existing projects, and explore technical concepts with
  research-backed depth. Triggers when the user wants to: (1) discuss or brainstorm a new project or
  product idea, (2) explore features or improvements for an existing project, (3) research a technology,
  library, API, or architectural pattern, (4) talk through ideas, concepts, or "what if" scenarios,
  (5) evaluate trade-offs between approaches, (6) plan or scope a new initiative, (7) capture interest
  in building something ("I've been thinking about...", "what if we...", "I want to build...",
  "wouldn't it be cool if...", "how could we...", "let's think about...", "I have an idea for...").
  Also triggers on explicit research requests like "research X", "look into Y", "find out about Z",
  "what are the best options for...", "compare X vs Y". Does NOT trigger for pure implementation
  tasks — only for ideation, exploration, and research phases.
---

# Brainstorm

Research-backed ideation for new projects and features, grounded in the user's existing codebase, memories, and external sources.

## Workflow

### 1. Gather Context

Before responding, silently gather relevant context:

- **Project context**: If discussing an existing project, read its code and docs:
  - Scan `/Users/ggomes/Projects/` for the project directory
  - Read README, package.json, or pyproject.toml for tech stack
  - Check `obsidian-vault/Projects/{project}/` for existing docs
  - See [references/projects.md](references/projects.md) for known project catalog
- **Memory context**: Read relevant memory files:
  - `memory/lessons-learned.md` — past gotchas and discoveries
  - `memory/workflows.md` — proven processes
  - `obsidian-vault/Ideas/Ideas.md` — existing ideas and plans
  - `obsidian-vault/Ekus/Knowledge/` — tool and API knowledge
- **Existing ideas**: Check if the topic already has notes in `obsidian-vault/Ideas/`

### 2. Research with NotebookLM

For any non-trivial topic, use `notebooklm` to create a research notebook. This is mandatory — brainstorming without research is just guessing.

```bash
# Create a focused research notebook
notebooklm create "Brainstorm: {topic}"

# Add relevant sources — web URLs, docs, articles
notebooklm source add -n {notebook_id} --url "https://relevant-article.com"
notebooklm source add -n {notebook_id} --url "https://docs.example.com/guide"

# Query the sources for specific insights
notebooklm chat -n {notebook_id} "What are the main approaches to {topic}?"
notebooklm chat -n {notebook_id} "What are the trade-offs between X and Y?"
```

**What to research:**
- Similar existing tools/products (competitive landscape)
- Libraries, APIs, or frameworks relevant to the idea
- Architectural patterns that apply
- Known pitfalls and best practices
- Community discussions and real-world experiences

**Source strategy:**
- Use WebSearch to find relevant URLs first, then add them as NotebookLM sources
- Add 3-8 high-quality sources per topic (docs, blog posts, GitHub repos, discussions)
- Prefer official docs, well-known blogs, and recent content
- Add the user's own project docs as sources when relevant (local file paths work)

### 3. Synthesize and Present

Structure the brainstorm output:

- **Context**: What we know (from codebase, memories, existing docs)
- **Research findings**: Key insights from NotebookLM with source references
- **Ideas/Options**: Concrete proposals with pros/cons
- **Recommendation**: Opinionated take on the best path forward
- **Next steps**: Actionable items if the user wants to proceed

### 4. Capture Outcomes

After the brainstorm session, if the user expresses interest in pursuing an idea:

- Save the idea to `obsidian-vault/Ideas/{idea-name}.md` with wikilinks and frontmatter
- Update `obsidian-vault/Ideas/Ideas.md` index
- If it's a feature for an existing project, add to that project's docs
- If it involves a task, offer to create a Trello card

## Guidelines

- **Have opinions.** Don't just list options — recommend one and say why.
- **Be concrete.** Propose specific tech stacks, architectures, file structures. Vague ideas are useless.
- **Connect the dots.** Reference the user's existing projects, skills, and infrastructure. "You already have X running, so you could reuse that for Y."
- **Challenge assumptions.** If an idea has a fatal flaw, say so early. Better to kill bad ideas fast.
- **Research depth scales with complexity.** Quick "what if" → 2-3 sources. Full project exploration → 5-8 sources with deep queries.
- **Always cite sources.** When presenting research findings, reference where the info came from.

## Resources

### references/
- [projects.md](references/projects.md) — Catalog of known projects in `/Users/ggomes/Projects/`
