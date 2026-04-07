# Training Resources README Redesign Design

Date: 2026-04-07
Repository: Public-Examples
Scope: `Training Resources/README.md`

## Goal
Redesign the Training Resources README for a mixed audience with balanced success across:
- Faster discovery
- Better progression
- Easier maintenance

Constraints:
- Markdown-only
- Manual maintenance (no scripts or automation)

## Recommended Approach
Use a dual-entry top section with two equal pathways:
- Start Learning
- Find by Topic

Why this approach:
- Supports both newcomers and power users without duplicating content
- Keeps one canonical resource body for easier maintenance
- Preserves manual editing simplicity

## Information Architecture
Top-level section order:
1. Overview and usage
2. Dual entry links
3. Recent additions
4. Learning paths
5. Topic index
6. Full courses
7. Deep dive content

Design principles:
- One shared content body after top navigation
- Stable anchor names for reliable jumps
- Clear section naming to minimize overlap and drift

## Component Layout Rules
Each major section should follow a repeatable pattern:
1. Purpose (1-2 lines)
2. Quick links (anchors)
3. Resource list

Entry blocks:
- Start Learning: 4-6 staged phases (for guided progression)
- Find by Topic: topic families that exactly match downstream headings

Resource formatting:
- Standard list item: Title + Link
- Avoid selective metadata unless uniformly applied in a section

Heading hierarchy:
- H1: document title
- H2: major navigation sections
- H3: topic groups
- H4: optional subclusters only when needed

Maintenance note (near top):
- Add new links to Recent Additions first
- Place each link in one canonical long-term section
- Remove duplicates

## Content Lifecycle and Data Flow
Manual lifecycle for each new resource:
1. Add to Recent Additions
2. Add to one canonical section under Full Courses or Deep Dive Content
3. Remove duplicates across sections

This keeps "new" content visible while preserving long-term organization.

## Error Handling and Quality Checks
Editorial checks for each update:
1. Validate newly added or modified links
2. Scan for duplicate URLs
3. Verify section/topic fit
4. Verify anchor links from top navigation
5. Split oversized sections into subheadings when needed

Dead or moved links:
- If unavailable, mark temporarily with a dated note (YYYY-MM-DD)
- Replace or remove in next update cycle
- Update URLs immediately when renamed/rehosted resources are identified

## Validation and Testing
Use a quick navigation test after changes:
- A newcomer should find a relevant learning path quickly
- A power user should locate a specific topic quickly

Acceptance heuristic:
- Both user types can find relevant content in about 30 seconds

## Non-Goals
- No automation for indexing, link checks, or section generation
- No content-type metadata model at this stage
- No repository-wide refactor outside Training Resources README

## Implementation Preview (Future)
When implementation starts:
1. Add dual-entry block and compact TOC near top
2. Normalize heading hierarchy and anchor consistency
3. Keep Recent Additions concise (high-signal)
4. Align Topic Index labels with canonical section headings
5. Do a final duplicate and anchor pass

## Decision Record
Final decisions captured from brainstorming:
- Audience: Mixed
- Navigation emphasis: Equal emphasis with two clear top entry points
- Maintenance model: Markdown-only, manual
- Success metric: Balanced across discovery, progression, maintenance
