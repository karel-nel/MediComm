# MediComm Codex Implementation Brief

## Purpose

This document is the handoff brief for Codex to implement the MediComm Rails 8 application.

It ties together:
- the overall technical specification
- the ERD
- the UI/UX specification

The goal is to ensure Codex builds the right application structure in the right order without drifting into the wrong abstractions.

---

## 1. Project Summary

MediComm is a Rails 8 SaaS application for medical practices.

It provides:
- a desktop-first admin application
- WhatsApp-based patient intake
- structured, configurable intake flows
- AI-assisted extraction and natural response phrasing
- secure file storage
- staff review and approval workflows

This is **not** a chatbot product.
It is a **structured intake engine** with a conversational front-end.

---

## 2. Core Build Principles

Codex must follow these rules:

1. **Rails owns orchestration**
   - Business logic lives in Rails.
   - Do not push core orchestration into external workflow tools.

2. **Field-based model, not script-step model**
   - The system is built around flows, fields, sessions, messages, attachments, and field values.
   - Do not implement a “step 1, step 2, step 3” bot engine.

3. **AI is assistive, not authoritative**
   - AI helps with phrasing and extraction.
   - AI does not decide what fields matter or whether the session is complete.

4. **Out-of-order capture is mandatory**
   - If a patient sends useful data early, absorb it and do not ask again.

5. **The review screen is the core product**
   - Prioritise sessions index and session detail/review before lower-priority screens like billing.

6. **Use seeded data first**
   - Build the UI with realistic seeded data before wiring full integrations.

---

## 3. Tech Stack Requirements

Codex should build using:

- Ruby on Rails 8
- PostgreSQL
- Hotwire
- Turbo
- Stimulus
- Tailwind CSS
- ViewComponent for reusable UI components
- Sidekiq for async jobs
- Redis for Sidekiq
- S3 integration points prepared
- WhatsApp Cloud API integration points prepared

Use server-rendered Rails views. Do not build a separate SPA frontend.

---

## 4. Initial Repository Tasks

Codex should first set up:

### Gems
- view_component
- devise
- sidekiq

Optional later:
- rspec-rails
- factory_bot_rails
- faker

### Initial setup tasks
1. Install gems
2. Install Devise
3. Configure ViewComponent
4. Configure Sidekiq routes and basic setup
5. Create admin namespace and layout
6. Create realistic seeds

---

## 5. Required Documentation Files in Repo

Codex should assume the repo includes or will include:

- `docs/medicomm_overall_tech_spec.md`
- `docs/medicomm_erd.md`
- `docs/medicomm_ui_ux_spec.md`
- `docs/codex_implementation_brief.md`

Codex must treat these files as the implementation contract.

---

## 6. Build Order

Codex must build in this exact order.

### Phase 1: App shell and authentication
Build:
- Devise auth
- admin namespace
- admin layout
- sidebar
- topbar
- placeholder dashboard page

Do not attempt WhatsApp or AI integration yet.

### Phase 2: Core UI with seeded data
Build:
- Overview dashboard
- Sessions index
- Session detail / review
- Flows index / editor

Use seeded fake records and presenter objects if needed.

### Phase 3: Real core models
Build:
- Practice
- User
- WhatsappAccount
- IntakeFlow
- IntakeFieldGroup
- IntakeField
- IntakeSession
- IntakeMessage
- IntakeAttachment
- IntakeFieldValue
- IntakeEvent
- SessionReview
- ExportedDocument

Add associations, enums, validations, indexes, and tenant scoping.

### Phase 4: Real admin persistence
Wire:
- flow editor persistence
- sessions listing from database
- session detail review from database
- seeded attachments/messages/field values

### Phase 5: Async pipeline foundations
Add:
- Sidekiq setup
- stub jobs
- session locking approach
- job classes for future WhatsApp/media/AI handling

### Phase 6: External integrations
Only now add:
- WhatsApp Cloud API webhook controller
- outbound messaging service
- Meta media download service
- S3 storage service
- AI extraction service
- AI response generation service

### Phase 7: Operational polish
Add:
- review actions
- audit trail rendering
- file previews/download actions
- error states
- loading states
- empty states

---

## 7. Rails Route Structure

Codex should implement:

```ruby
Rails.application.routes.draw do
  devise_for :users

  namespace :admin do
    root "dashboard#index"

    resources :sessions, only: [:index, :show]
    resources :flows, only: [:index, :show, :edit, :update]
    resource :whatsapp, only: [:show]
    resources :files, only: [:index, :show]
    resources :team_members, only: [:index]
    resource :billing, only: [:show]
    resource :settings, only: [:show, :update]
  end

  namespace :webhooks do
    resource :whatsapp, only: [:show, :create]
  end

  root "admin/dashboard#index"
end
```

Codex may adjust details slightly, but the admin namespace structure should remain intact.

---

## 8. Required Models

Codex must create these models first.

### Practice
Tenant boundary.

### User
Belongs to practice. Use Devise.
Support roles such as:
- owner
- admin
- staff
- read_only

### WhatsappAccount
Belongs to practice.

### IntakeFlow
Belongs to practice.
Created by a user.

### IntakeFieldGroup
Belongs to intake flow.

### IntakeField
Belongs to intake flow and optional group.

### IntakeSession
Belongs to practice, flow, whatsapp account, initiating user.

### IntakeMessage
Belongs to session.

### IntakeAttachment
Belongs to session and optionally a message.

### IntakeFieldValue
Belongs to session and field.
May reference a source message and/or source attachment.
May reference a verifying user.

### IntakeEvent
Belongs to session.

### SessionReview
Belongs to session and reviewer.

### ExportedDocument
Belongs to session.

---

## 9. Initial Enums and Statuses

Codex should add enums where appropriate.

### User role
- owner
- admin
- staff
- read_only

### IntakeFlow status
- draft
- published
- archived

### IntakeSession status
- pending_start
- active
- awaiting_patient
- processing
- awaiting_staff_review
- completed
- abandoned
- failed

### IntakeFieldValue status
- missing
- candidate
- complete
- needs_clarification
- skipped
- rejected
- inferred

### SessionReview status
- pending
- approved
- needs_follow_up

---

## 10. Initial Database Constraints

Codex must add:
- foreign keys
- non-null constraints on ownership fields
- indexes on all foreign keys
- unique index on `practices.slug`
- unique index on `users.email`
- unique index on `intake_fields` per flow by `key`
- unique index on `intake_messages.provider_message_id` when present
- tenant scoping indexes for session-heavy tables

Do not rely only on Rails model validations.

---

## 11. Folder and Code Structure

Codex should organise the app cleanly.

### Controllers
Use namespaced controllers under:
- `app/controllers/admin`
- `app/controllers/webhooks`

### Components
Use ViewComponent under:
- `app/components/admin`

Recommended first components:
- `Admin::SidebarComponent`
- `Admin::TopbarComponent`
- `Admin::MetricCardComponent`
- `Admin::StatusBadgeComponent`
- `Admin::PageHeaderComponent`
- `Admin::SessionsTableComponent`
- `Admin::FieldGroupCardComponent`
- `Admin::TranscriptPanelComponent`
- `Admin::AttachmentsPanelComponent`
- `Admin::AuditPanelComponent`

### Services
Use service objects under:
- `app/services/whatsapp`
- `app/services/sessions`
- `app/services/fields`
- `app/services/attachments`
- `app/services/conversation`
- `app/services/exports`
- `app/services/ai`

### Jobs
Use:
- `app/jobs`

---

## 12. UI Implementation Rules

Codex must build the UI according to the UI/UX spec.

### Global UI rules
- desktop-first
- calm, operational, clean
- sidebar + topbar shell
- strong spacing and hierarchy
- reusable components
- avoid overdesigned dashboards

### Priority screens
1. Overview dashboard
2. Sessions index
3. Session detail / review
4. Flows editor

These are the first screens that must feel production-grade.

### Session detail screen
This is the most important UI.

It must include:
- header with patient/session status
- progress indicator
- grouped field values on the left
- transcript/files/audit tabs on the right
- approve and follow-up actions

### Flows editor
This must configure:
- fields
- groups
- required/optional state
- branch/visibility hints
- extraction hints
- tone/language at flow level

Do not create a script-writing UI.

---

## 13. Seeding Requirements

Before real integrations, Codex should create realistic demo data.

Seeds should include:
- 1 practice
- 3-4 users
- 1 WhatsApp account
- 2 intake flows
- field groups and fields
- 4 intake sessions in different statuses
- realistic intake messages
- realistic attachments
- field values with confidence levels
- audit events
- review states

The UI must look complete and believable immediately after `db:seed`.

---

## 14. Presenter / Query Object Guidance

Codex should not dump heavy query logic into views.

Recommended:
- use presenters or query objects for dashboard metrics
- use eager loading for session detail pages
- avoid N+1 issues in sessions index
- keep controllers thin

Possible classes:
- `Admin::DashboardMetrics`
- `Admin::SessionsQuery`
- `Admin::SessionDetailPresenter`

---

## 15. Authentication and Access Rules

Codex should:
- require authentication for all admin pages
- scope data to current practice
- prevent cross-practice access
- use a simple `current_practice` concept through the logged-in user

No complex multi-practice switching UI is needed for MVP.

---

## 16. Service Object Plan

Codex should scaffold these service objects as placeholders even before full logic:

### WhatsApp
- `Whatsapp::WebhookParser`
- `Whatsapp::SignatureVerifier`
- `Whatsapp::SendMessage`

### Sessions
- `Sessions::FindOrCreate`
- `Sessions::LockAndProcess`
- `Sessions::Complete`

### Fields
- `Fields::ExtractCandidates`
- `Fields::ApplyCandidates`
- `Fields::ResolveBranches`
- `Fields::ComputeOutstanding`

### Attachments
- `Attachments::DownloadFromMeta`
- `Attachments::StoreToS3`
- `Attachments::RunExtraction`

### Conversation
- `Conversation::SelectNextAsk`
- `Conversation::GenerateReply`

### Exports
- `Exports::BuildCompletionEmail`

### AI
- `AI::ExtractStructuredFields`
- `AI::GenerateReply`

These can begin as stubs with clear TODOs.

---

## 17. Job Plan

Codex should add job classes, even if some are stubbed initially:

- `ProcessIncomingWhatsappWebhookJob`
- `DownloadWhatsappMediaJob`
- `StoreAttachmentJob`
- `ExtractAttachmentTextJob`
- `ExtractFieldCandidatesJob`
- `ApplyFieldCandidatesJob`
- `GenerateConversationReplyJob`
- `SendWhatsappMessageJob`
- `SendCompletionEmailJob`

Do not fully wire them until the core models and UI are stable.

---

## 18. What Codex Must Not Do

Codex must avoid these mistakes:

1. Do not build a chatbot step engine.
2. Do not create a React/Vue SPA.
3. Do not skip seeded data.
4. Do not wire WhatsApp/AI before the admin shell and session UI exist.
5. Do not bury the UI in generic scaffold templates.
6. Do not make billing or settings the first polished screens.
7. Do not place core orchestration logic in controllers.
8. Do not assume AI output is always correct.
9. Do not skip auditability on manual edits.

---

## 19. First Milestone Definition

Codex’s first milestone should be considered complete only when:

- Devise auth works
- admin layout exists
- sidebar and topbar are reusable
- dashboard page exists with realistic seeded data
- sessions index is implemented and styled
- session detail review screen is implemented and styled
- flows index/editor exists in usable seeded form
- seeded data loads cleanly
- app boots and looks coherent

That is the correct first “real” milestone.

---

## 20. Second Milestone Definition

Second milestone:

- real database-backed flows
- real database-backed sessions
- real session detail hydration
- file/attachment associations visible
- field values and confidence states backed by DB
- review actions scaffolded
- ViewComponents extracted/refined

Only after that should messaging integrations begin.

---

## 21. Suggested Prompting Strategy for Codex

Do not give Codex one giant “build the entire app” command.

Use focused tasks such as:

### Task 1
Set up Devise, ViewComponent, admin layout, sidebar, and topbar.

### Task 2
Implement dashboard, sessions index, and seeded data.

### Task 3
Implement session detail review UI with grouped fields, transcript, files, and audit tabs.

### Task 4
Implement flows index and flows editor UI.

### Task 5
Create the core models and migrations from the ERD.

### Task 6
Wire database-backed admin pages.

This keeps Codex sharp instead of vague.

---

## 22. Final Instruction to Codex

Build MediComm as a structured intake platform with a calm, operational Rails admin interface.

Prioritise:
- admin shell
- sessions review workflow
- flows configuration
- proper domain modeling
- clean, reusable components
- seeded realism

Defer:
- heavy integrations
- advanced automation
- lower-priority admin sections

The application should feel like a trustworthy medical operations tool, not a chatbot demo and not a scaffold dump.
