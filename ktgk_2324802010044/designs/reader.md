# 1

## Mission
Create implementation-ready, token-driven UI guidance for 1 that is optimized for consistency, accessibility, and fast delivery across dashboard web app.

## Brand
- Product/brand: 1
- URL: https://mangadex.org/chapter/86d45eef-084e-4b6f-aa32-65de2ea5d18e
- Audience: authenticated users and operators
- Product surface: dashboard web app

## Style Foundations
- Visual style: clean, functional, implementation-oriented
- Main font style: `font.family.primary=Poppins`, `font.family.stack=Poppins, sans-serif`, `font.size.base=16px`, `font.weight.base=400`, `font.lineHeight.base=24px`
- Typography scale: `font.size.xs=12px`, `font.size.sm=14px`, `font.size.md=16px`
- Color palette: `color.text.primary=#ffffff`, `color.text.secondary=#ff6740`, `color.text.tertiary=#3498db`, `color.surface.base=#000000`, `color.surface.raised=#2c2c2c`, `color.border.default=#e5e7eb`
- Spacing scale: `space.1=2px`, `space.2=4px`, `space.3=8px`, `space.4=12px`, `space.5=16px`, `space.6=95.34px`, `space.7=107.19px`, `space.8=215px`
- Radius/shadow/motion tokens: `radius.xs=4px`, `radius.sm=8px`, `radius.md=9999px` | `motion.duration.instant=75ms`, `motion.duration.fast=100ms`

## Accessibility
- Target: WCAG 2.2 AA
- Keyboard-first interactions required.
- Focus-visible rules required.
- Contrast constraints required.

## Writing Tone
Concise, confident, implementation-focused.

## Rules: Do
- Use semantic tokens, not raw hex values, in component guidance.
- Every component must define states for default, hover, focus-visible, active, disabled, loading, and error.
- Component behavior should specify responsive and edge-case handling.
- Interactive components must document keyboard, pointer, and touch behavior.
- Accessibility acceptance criteria must be testable in implementation.

## Rules: Don't
- Do not allow low-contrast text or hidden focus indicators.
- Do not introduce one-off spacing or typography exceptions.
- Do not use ambiguous labels or non-descriptive actions.
- Do not ship component guidance without explicit state rules.

## Guideline Authoring Workflow
1. Restate design intent in one sentence.
2. Define foundations and semantic tokens.
3. Define component anatomy, variants, interactions, and state behavior.
4. Add accessibility acceptance criteria with pass/fail checks.
5. Add anti-patterns, migration notes, and edge-case handling.
6. End with a QA checklist.

## Required Output Structure
- Context and goals.
- Design tokens and foundations.
- Component-level rules (anatomy, variants, states, responsive behavior).
- Accessibility requirements and testable acceptance criteria.
- Content and tone standards with examples.
- Anti-patterns and prohibited implementations.
- QA checklist.

## Component Rule Expectations
- Include keyboard, pointer, and touch behavior.
- Include spacing and typography token requirements.
- Include long-content, overflow, and empty-state handling.
- Include known page component density: inputs (64), links (54), buttons (37), lists (4).


## Quality Gates
- Every non-negotiable rule must use "must".
- Every recommendation should use "should".
- Every accessibility rule must be testable in implementation.
- Teams should prefer system consistency over local visual exceptions.
