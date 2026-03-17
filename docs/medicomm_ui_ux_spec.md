# MediComm UI/UX Specification

## Purpose

This document defines the UI/UX direction for the MediComm admin application. It is the implementation-facing companion to the ERD and technical spec.

The product must feel:

- calm
- fast
- trustworthy
- operationally clear
- simple for non-technical medical staff

This is not generic hospital software. It is a focused intake operations platform.

---

## Core UX Principles

### 1. Simplicity first
The first-time doctor or receptionist must not feel overwhelmed.

Rules:
- keep primary navigation short
- show only essential actions at first glance
- reduce clutter
- prefer one obvious primary action per screen

This aligns with the project requirement that onboarding for a new doctor must be exceedingly simple. See the concept document.

### 2. Operations over decoration
Every screen must help staff process work, review captured data, or configure intake requirements.

Avoid:
- decorative analytics with no operational value
- noisy charts
- unnecessary modals
- dense control panels

### 3. AI should feel invisible
The user should feel that the system is intelligent, but never out of control.

The UI must reinforce:
- deterministic field capture
- clear confidence states
- visible audit history
- staff override ability

### 4. Review is a first-class workflow
The most important screen in the system is the intake session review screen.

It must make it easy to:
- review extracted values
- inspect source messages and files
- correct errors
- approve or request follow-up

### 5. Desktop first
The admin app is primarily for desktop/laptop use in a practice environment.

Responsive support is good, but design for:
- 1440px desktop
- 1280px laptop
- usable down to tablet widths

---

## Information Architecture

Primary navigation:

- Overview
- Sessions
- Flows
- WhatsApp
- Files
- Team
- Billing
- Settings

### Navigation model
Use a persistent left sidebar with:
- product logo / practice identity
- primary nav items
- active state
- optional small operational summary card near the bottom

Use a top bar with:
- search
- contextual actions
- notifications / alerts
- user avatar / menu

---

## App Shell

### Sidebar
Requirements:
- fixed left sidebar on desktop
- clear active state
- compact icon + label rows
- no nested navigation in MVP

Behavior:
- active item visually dominant
- hover states subtle and clean
- labels always visible on desktop

### Top bar
Requirements:
- global search input
- filters shortcut
- primary CTA button such as "Start intake"
- alerts button
- user avatar/menu

Behavior:
- sticky on scroll
- minimal height
- no oversized headers

---

## Design Language

### Visual tone
The design should feel:
- modern
- clean
- calm
- healthcare-adjacent
- highly legible

Avoid:
- loud gradients everywhere
- overly playful UI
- sterile enterprise gray sludge

### Color approach
Base palette:
- slate / neutral background tones
- white card surfaces
- teal accents for trust / progress
- blue accents for system / navigation
- amber for attention
- rose/red for errors / failures
- emerald/teal for success / completion

### Component styling
- rounded cards
- soft borders
- subtle shadows
- clean spacing
- dense enough for operations, but never cramped

### Typography
Use a clean sans-serif system.

Hierarchy:
- page title: large, strong
- section title: medium, semibold
- body: regular, readable
- metadata: smaller, muted
- table text: compact, high contrast

---

## Core Components

### 1. Metric card
Used on dashboard.

Contains:
- label
- primary value
- small delta or support text
- icon

Should feel compact and scannable.

### 2. Status badge
Used everywhere.

Required statuses:
- Active
- Awaiting review
- Completed
- Needs follow-up
- Failed
- Connected
- Healthy
- High confidence
- Medium confidence
- Low confidence
- Complete
- Needs clarification
- Missing

Rules:
- consistent color mapping
- small rounded pill style
- readable at a glance

### 3. Data table
Used for sessions, files, team, invoices.

Rules:
- generous row spacing
- visible hover state
- strong primary text in first column
- muted metadata beneath if needed
- row click or explicit action button, not both fighting each other

### 4. Progress indicator
Used in session progress.

Rules:
- simple horizontal bar
- show percent or completion ratio
- never overly stylized

### 5. Field state row
Used in session review.

Contains:
- field label
- captured value
- status badge
- confidence indicator
- actions such as edit or audit

This is one of the most important reusable components.

### 6. Transcript bubble
Used in session detail.

Rules:
- system and patient messages clearly differentiated
- timestamp visible but subdued
- long messages remain readable
- no chat gimmicks

### 7. Attachment card
Used in files and session detail.

Contains:
- file type icon
- name
- type / size
- processing status
- action button

### 8. Audit event item
Used in session audit trail.

Rules:
- chronological
- compact
- clear language
- structured enough for debugging and review

### 9. Slide-over / drawer
Used for:
- adding/editing fields
- quick actions
- configuration forms

Rules:
- use drawers for focused editing
- do not hide critical workflows inside too many nested drawers

### 10. Modal
Use sparingly for:
- confirmations
- invitations
- destructive actions

---

## Screen Specifications

## 1. Overview Dashboard

### Purpose
Give staff a quick operational snapshot and immediate path into the work queue.

### Must include
- key metrics
- today’s queue or priority sessions
- channel/WhatsApp health
- recent activity

### UX rules
- do not overload with analytics
- dashboard is a launchpad, not a BI tool
- priority sessions must be visible without scrolling too far

---

## 2. Sessions Index

### Purpose
Main intake operations queue.

### Must include
- searchable session table
- filters by status
- filters by flow
- filters by confidence
- owner / assignee
- progress
- missing fields summary
- last updated timestamp

### UX rules
- this should be highly scannable
- statuses and confidence must be immediately obvious
- filters should be inline and lightweight
- bulk actions can exist, but should not dominate the UI

---

## 3. Session Detail / Review Screen

### Purpose
Core product screen.

### Layout
Use split-pane or two-column layout:

Left side:
- grouped field values
- status and confidence indicators
- edit actions
- progress

Right side:
- transcript
- files
- audit trail via tabs

### Must include
- patient/session header
- flow name
- status
- progress
- approve session action
- request follow-up action

### UX rules
- reviewing and correcting data must feel fast
- the source of truth should be inspectable
- confidence states must be visible, not hidden
- unresolved fields should stand out without screaming

### Tabs on right panel
- Transcript
- Files
- Audit

---

## 4. Flows Index / Editor

### Purpose
Allow staff/admin to configure intake requirements without scripting bot messages.

### Flow settings section
Must include:
- flow name
- language
- tone preset
- completion email recipients
- skip behavior
- extraction behavior
- out-of-order absorption toggle or equivalent configuration

### Group editor
Each group should show:
- group title
- description
- ordered field rows
- edit rules action

### Field editor
Must allow:
- label
- field type
- required / optional
- group
- validation hint
- extraction hint
- branch / visibility behavior

### UX rules
- no chatbot script writer
- structure first, language second
- field management must feel safer than editing code

---

## 5. WhatsApp Screen

### Purpose
Operational visibility into WhatsApp Cloud API status.

### Must include
- connection details
- phone number identity
- webhook status
- delivery log
- token / reconnect action

### UX rules
- this is an operational settings screen
- expose useful status, not low-level noise
- failures should be obvious and actionable

---

## 6. Files Screen

### Purpose
Review patient uploads and generated artifacts.

### Must include
- file listing
- type
- session association where relevant
- processing status
- file access action

### UX rules
- files must feel private and controlled
- do not imply public URLs
- generated files and patient uploads must be distinguishable

---

## 7. Team Screen

### Purpose
Manage practice staff access.

### Must include
- name
- role
- access summary
- last active
- status
- invite action

### UX rules
- roles must be clear
- avoid permission complexity in MVP
- security and simplicity matter more than granularity

---

## 8. Billing Screen

### Purpose
Show subscription and invoices without becoming a finance app.

### Must include
- current plan
- renewal date
- payment method summary
- usage snapshot
- invoice history

### UX rules
- compact and clear
- lower priority than sessions and flows
- no over-designed charts

---

## 9. Settings Screen

### Purpose
Store practice-level defaults and security behavior.

### Must include
- practice profile
- timezone
- support/billing email
- security toggles
- masking/privacy defaults

### UX rules
- simple forms
- safe defaults
- security-sensitive settings easy to understand

---

## Interaction Patterns

### Search
Global search in top bar should support:
- patient name
- phone number
- session ID

### Filters
Inline filters on queue screens.
Use:
- dropdowns
- status pills
- simple reset behavior

### Inline edit
Allowed on review screens for field corrections.

Rules:
- edits must feel safe
- audit should exist behind the scenes
- do not overload with complex form states

### Approval flow
Reviewer should be able to:
- approve
- request follow-up
- leave notes

### Empty states
Every major list screen should have a good empty state.

Examples:
- no sessions yet
- no flows configured
- no files available
- no team members invited

Empty states should direct the user to the next best action.

### Error states
Need clear UI for:
- WhatsApp connection issue
- failed delivery
- low-confidence extraction
- missing required attachment
- session cannot complete

---

## Accessibility and Usability

### Minimum standards
- strong text contrast
- keyboard-friendly forms and actions
- visible focus states
- adequate click targets
- no reliance on color alone for status meaning

### Reading comfort
Medical admin staff will use this for long periods.
Prioritize:
- clear spacing
- predictable layouts
- low visual fatigue

---

## UX Rules for AI-Driven Behaviors

The UI must reinforce that AI is assistive, not autonomous.

### Show:
- confidence states
- source attachments
- source messages
- audit trail
- ability to edit / override

### Never imply:
- that AI is always correct
- that extracted fields are final without review
- that conversational tone equals business logic control

---

## MVP Priorities

Build these first:

1. App shell
2. Overview dashboard
3. Sessions index
4. Session detail review
5. Flows editor

Build later:
6. WhatsApp settings
7. Files
8. Team
9. Billing
10. Settings

This order matters. The product lives or dies on the review and flow configuration experience.

---

## Final UX Position

MediComm should feel like:

- a calm operational cockpit
- a trustworthy review workspace
- a clean SaaS product for practices
- an AI-assisted intake tool with human control

It must not feel like:
- a chatbot toy
- bloated hospital software
- generic CRM sludge
- an uncontrolled AI experiment
