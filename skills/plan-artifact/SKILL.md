---
name: plan-artifact
description: Analyze requirements before implementation and create a detailed execution plan
---

# Plan Artifact Skill

## Purpose

This skill analyzes user requirements before implementation to create a comprehensive, structured execution plan. It ensures the agent fully understands the scope, identifies potential challenges, and establishes a clear roadmap before writing any code.

## When to Use

- **ALWAYS** use this skill when the "Requirements Analysis" refinement is enabled
- Before starting any new artifact or major feature implementation
- When the user's request is complex or ambiguous
- When multiple approaches could satisfy the requirements

## Instructions

Follow these steps to create an effective implementation plan:

### Step 1: Understand the Request

1. Read the user's prompt carefully
2. Identify the core objective (what do they want to achieve?)
3. Note any specific requirements mentioned
4. List any constraints (technology, time, compatibility)

### Step 2: Analyze Complexity

Evaluate the request across these dimensions:

| Dimension | Low | Medium | High |
|-----------|-----|--------|------|
| **Scope** | Single component | Multiple components | Full application |
| **Integration** | Standalone | 1-2 external services | Multiple integrations |
| **UI Complexity** | Basic layout | Interactive forms | Rich animations/charts |
| **Data** | Static content | Simple state | Complex state/persistence |

### Step 3: Create the Plan Structure

Output a plan in this format:

## Implementation Plan

### 1. Overview
[One paragraph summary of what will be built]

### 2. Components to Create
- [ ] Component 1 - Description
- [ ] Component 2 - Description
- [ ] ...

### 3. Technical Approach
- Framework/libraries to use
- Key patterns or architecture decisions
- Data flow overview

### 4. Implementation Order
1. **Phase 1:** [Foundation] - Description
2. **Phase 2:** [Core Features] - Description
3. **Phase 3:** [Polish] - Description

### 5. Potential Challenges
- Challenge 1 and mitigation strategy
- Challenge 2 and mitigation strategy

### 6. Success Criteria
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] ...

### Step 4: Present and Confirm

**If mode is "automatic":**
- Present the plan briefly and proceed with implementation
- Say: "Here's my implementation plan: [summary]. Proceeding with implementation..."

**If mode is "interactive":**
- Present the full plan and ask for confirmation
- Say: "Here's my proposed plan. Would you like me to proceed, or would you like any changes?"
- Wait for user response before implementing

## Input Expected

- User prompt describing what to build
- Artifact type information (if selected)
- Any existing project context
- Integration requirements (if any)

## Output Expected

A structured implementation plan that:
1. Demonstrates understanding of requirements
2. Breaks down the work into manageable phases
3. Identifies risks and mitigation strategies
4. Defines clear success criteria
5. Provides estimated component count

## Iteration Handling

This skill does not iterate. It produces one plan before implementation begins. If the user requests changes to the plan during interactive mode, update the plan accordingly before proceeding.

## Examples

### Example 1: Simple Landing Page

**User Request:** "Create a landing page for a fitness app"

**Plan Output:**
- Overview: A modern landing page featuring hero, features, testimonials, and CTA sections
- Components: Hero section, Features grid, Testimonials carousel, Footer
- Technical: Static HTML/CSS, responsive design, CSS animations
- Phases: Structure -> Content sections -> Polish
- Challenges: Image assets (use placeholders), Content (create samples)
- Criteria: Responsive, clear CTA above fold, fast loading

### Example 2: Complex Dashboard

**User Request:** "Build a sales analytics dashboard with charts"

**Plan Output:**
- Overview: Interactive analytics dashboard with visualizations and filters
- Components: Layout, KPI cards, Line chart, Bar chart, Filters, Data table
- Technical: React with Chart.js, centralized state for filters
- Phases: Layout -> Charts -> Filters -> Polish
- Challenges: Chart responsiveness, Filter state management, Performance
- Criteria: Charts render correctly, Filters work, Responsive layout

## Important Notes

- The plan should be concise but comprehensive
- Focus on actionable items, not abstract concepts
- Always identify what could go wrong and how to handle it
- The plan sets expectations - don't over-promise
- If something is unclear, flag it in the plan rather than assuming
