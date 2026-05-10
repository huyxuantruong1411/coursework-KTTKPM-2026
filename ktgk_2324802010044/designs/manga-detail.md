# Youkai Ou Kyun Gakuen

## Mission
Create implementation-ready, token-driven UI guidance for Youkai Ou Kyun Gakuen that is optimized for consistency, accessibility, and fast delivery across dashboard web app.

## Brand
- Product/brand: Youkai Ou Kyun Gakuen
- URL: https://mangadex.org/title/873cceec-7e16-4191-8bb0-8887ba3933e3/youkai-ou-kyun-gakuen
- Audience: readers and knowledge seekers
- Product surface: dashboard web app

## Style Foundations
- Visual style: structured, tokenized, content-first
- Main font style: `font.family.primary=Poppins`, `font.family.stack=Poppins, sans-serif`, `font.size.base=14px`, `font.weight.base=400`, `font.lineHeight.base=20px`
- Typography scale: `font.size.xs=10px`, `font.size.sm=12px`, `font.size.md=14px`, `font.size.lg=16px`, `font.size.xl=72px`
- Color palette: `color.text.primary=#ffffff`, `color.text.secondary=#3498db`, `color.text.tertiary=#2ecc71`, `color.text.inverse=#808080`, `color.surface.base=#000000`, `color.surface.muted=#2c2c2c`, `color.border.default=#e5e7eb`, `color.border.strong=#ff6740`
- Spacing scale: `space.1=2px`, `space.2=4px`, `space.3=5px`, `space.4=6px`, `space.5=8px`, `space.6=12px`, `space.7=14px`, `space.8=16px`
- Radius/shadow/motion tokens: `radius.xs=4px`, `radius.sm=8px`, `radius.md=9999px` | `motion.duration.instant=75ms`, `motion.duration.fast=100ms`, `motion.duration.normal=150ms`

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
- Include known page component density: links (118), inputs (64), buttons (46), lists (3), tables (1).

- Extraction diagnostics: Audience and product surface inference confidence is low; verify generated brand context.

## Quality Gates
- Every non-negotiable rule must use "must".
- Every recommendation should use "should".
- Every accessibility rule must be testable in implementation.
- Teams should prefer system consistency over local visual exceptions.
