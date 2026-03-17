# MediComm Overall Technical Specification

## 1. Project Overview

MediComm is a WhatsApp-first patient intake platform for medical practices.

Its purpose is to collect new patient information before the patient arrives at the practice, reduce front-desk bottlenecks, gather supporting documents such as ID and medical aid card photos, and prepare structured data for staff review and later downstream automation.

The platform is designed as a subscription SaaS product for practices, with a very simple onboarding experience for new doctors and room to expand into multiple intake flows, document generation, signatures, and ERM integration later.

---

## 2. Product Goals

### Primary goals
- collect structured patient intake data through WhatsApp
- allow practices to configure intake requirements without scripting chatbot steps
- accept out-of-order patient responses and absorb useful information immediately
- store files securely
- allow staff to review, correct, and approve captured data
- provide a clean operational admin interface

### Secondary goals
- prepare for later PDF autofill
- prepare for later digital signature workflows
- prepare for later ERM/practice management integration
- support multiple intake flow types beyond new patient intake

---

## 3. Core Product Model

This system is **not** a free-roaming chatbot.

It is a **deterministic intake engine** with an AI-assisted conversational layer.

### Deterministic layer owns
- required fields
- branching rules
- session completion logic
- validation
- missing-field computation
- evidence/source tracking
- auditability

### AI layer owns
- natural phrasing
- acknowledgements
- summarising what was received
- graceful handling of out-of-order replies
- tone and language rendering

AI must never be the source of truth for what the practice needs or whether a required field has actually been captured.

---

## 4. Technology Stack

## Backend
- Ruby on Rails 8
- PostgreSQL
- Sidekiq
- Redis

## Frontend / Admin UI
- Rails server-rendered views
- Hotwire
- Turbo
- Stimulus
- Tailwind CSS
- ViewComponent recommended for reusable UI pieces

## Messaging
- WhatsApp Cloud API

## File Storage
- Amazon S3 private bucket
- signed URL access only

## AI
- OpenAI API for:
  - structured extraction from text/OCR content
  - natural response generation

## Email
- Postmark or Amazon SES for summary emails and notifications

## Deployment
- Kamal-ready Rails deployment
- production background workers
- production Redis
- production Postgres
- production S3

---

## 5. Architectural Principles

### 5.1 Rails owns the product logic
The product’s orchestration belongs in Rails.

Do not put core intake logic in n8n or any external workflow engine.

### 5.2 Field-based modeling, not script-step modeling
The platform must be modeled around:
- flows
- fields
- sessions
- messages
- attachments
- field values

Do not design the system as:
- bot step 1
- bot step 2
- bot step 3

The engine should always ask:
**What required data is still unresolved?**

### 5.3 One session can resolve fields in any order
A patient may:
- send ID before being asked
- send multiple answers in one message
- upload medical aid card early
- answer later questions before earlier ones

The system must absorb valid data regardless of order and never ask again for fields already marked complete.

### 5.4 Human review is a first-class workflow
Extracted data is not final until reviewed or confidently validated.

The staff review workspace is a core product surface, not an admin afterthought.

---

## 6. High-Level System Design

### Core components
1. Admin web app
2. WhatsApp webhook/API layer
3. Session orchestration engine
4. AI extraction service
5. AI response generation service
6. File storage service
7. Background job system
8. Review and audit layer

### Runtime flow
1. Patient message arrives through WhatsApp Cloud API
2. Webhook saves inbound event
3. Processing job normalises the message
4. Media is downloaded if present
5. Media is stored in S3
6. OCR / extraction runs if needed
7. Candidate field values are generated
8. Validators accept, reject, or flag clarifications
9. Session state is updated
10. Missing fields are recomputed
11. AI generates a natural next response from an allowed ask list
12. Outbound reply is sent
13. Audit events are logged

---

## 7. Domain Model Summary

Main domains:
- tenancy and users
- WhatsApp account config
- intake flow configuration
- runtime intake sessions
- messages and attachments
- field values and evidence sources
- audit trail
- exported outputs

### Core entities
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

---

## 8. ERD Summary

### Practice
The tenant boundary.

### User
Admin/staff/doctor access within a practice.

### WhatsappAccount
Practice-level WhatsApp Cloud API connection.

### IntakeFlow
Reusable intake definition for a practice.

### IntakeFieldGroup
Logical grouping of fields, e.g. patient details, medical aid, next of kin.

### IntakeField
Single canonical data point definition.

### IntakeSession
One real patient intake conversation.

### IntakeMessage
Inbound/outbound WhatsApp message record.

### IntakeAttachment
Uploaded image/document or generated artifact.

### IntakeFieldValue
Captured value for a field in a session, including source, confidence, and status.

### IntakeEvent
Audit event for system actions.

### SessionReview
Staff review state and notes.

### ExportedDocument
Later-generated summary, PDF, or signed output.

---

## 9. Session State Model

An intake session should move through statuses such as:
- pending_start
- active
- awaiting_patient
- processing
- awaiting_staff_review
- completed
- abandoned
- failed

A field value should move through statuses such as:
- missing
- candidate
- complete
- needs_clarification
- skipped
- rejected
- inferred

The system should compute session completion based on field states, not based on fixed chat steps.

---

## 10. Intake Flow Configuration

Practices configure intake flows in the admin app.

### Configurable at flow level
- flow name
- description
- language
- tone preset
- completion email recipients
- skip policy
- extraction policy
- active/published status

### Configurable at field level
- label
- key
- field type
- required/optional
- ask priority
- validation rules
- branch visibility rules
- extraction hint
- example values
- later PDF mapping key

### Configurable group examples
- patient details
- debtor/main member
- medical aid
- next of kin
- referral
- uploads

---

## 11. Conversation Engine Specification

The conversation engine is deterministic.

### Input sources
- message text
- attachments
- OCR results
- existing session values
- branch conditions
- admin flow schema

### Responsibilities
- identify field candidates
- apply validators
- update field statuses
- calculate unresolved required fields
- decide whether clarification is needed
- build the shortlist of next allowed asks

### Rules
1. Never ask for a field already complete.
2. If a message resolves multiple fields, store all of them.
3. If a document resolves a field, mark it complete if confidence and validation pass.
4. If confidence is low, request clarification before moving on.
5. AI may only phrase from the allowed ask shortlist.
6. Required fields cannot silently disappear because AI forgot them.
7. Skip only applies if the field or flow allows it.

---

## 12. AI Service Design

AI must be split into two responsibilities.

## 12.1 Extraction service
Purpose:
Turn text or OCR into structured candidate values.

### Inputs
- field schema subset
- existing known values
- incoming text
- OCR text
- attachment metadata
- branch context

### Outputs
- field candidates
- confidence scores
- notes
- clarification flags

## 12.2 Response generation service
Purpose:
Write the human-sounding WhatsApp reply.

### Inputs
- newly accepted data
- clarification needs
- unresolved field shortlist
- tone and language
- recent transcript

### Outputs
- reply text
- referenced next asks

### Hard AI rules
- do not invent captured data
- do not confirm unresolved fields as complete
- do not ask outside the allowed shortlist
- thank the user for useful unsolicited data
- keep messages concise and natural

---

## 13. Validation and Normalisation

### Deterministic validators
- phone number normalisation to E.164
- email validation
- yes/no branch response parsing
- South African ID format/checksum
- mime type checks for uploads
- file size limits
- required attachment checks

### Cross-field validation
- if patient_same_as_debtor = true, suppress duplicate patient identity asks
- if medical_aid_name = Private, suppress aid-plan/member-number rules if configured
- if referred_by_doctor = false, hide referral fields

### Confidence thresholds
Recommended defaults:
- >= 0.92 auto-complete
- 0.75 to 0.91 candidate or needs clarification
- < 0.75 do not auto-complete

Critical identifiers may require stricter thresholds.

---

## 14. WhatsApp Cloud API Integration

### Inbound webhook
- verify webhook
- parse payload
- persist raw data
- identify inbound messages and statuses
- enforce idempotency by provider message id
- enqueue background processing
- return success quickly

### Outbound messaging
- send text replies
- later send templates where needed
- store provider response
- store delivery/read states from callbacks

### Media handling
- fetch media from Meta using media ids
- store privately in S3
- retain metadata and hashes
- run extraction pipeline if relevant

---

## 15. File Storage Specification

### Storage rules
- private S3 bucket
- object encryption
- structured object keys
- signed URL access only
- no public file exposure

### Typical object keys
- practice/{practice_id}/session/{session_id}/uploads/{uuid}.jpg
- practice/{practice_id}/session/{session_id}/generated/{uuid}.pdf

### Stored file types
- ID images
- medical aid card images
- later signed forms
- generated PDF summaries
- imported attachments

### Attachment metadata
- mime type
- original filename
- sha256
- size
- dimensions/pages
- extraction status
- virus scan status if implemented

---

## 16. Background Jobs

Sidekiq jobs should handle asynchronous work.

### Recommended jobs
- ProcessIncomingWhatsappWebhookJob
- DownloadWhatsappMediaJob
- StoreAttachmentJob
- ExtractAttachmentTextJob
- ExtractFieldCandidatesJob
- ApplyFieldCandidatesJob
- GenerateConversationReplyJob
- SendWhatsappMessageJob
- SendCompletionEmailJob
- RetryFailedOutboundMessageJob
- CloseCompletedSessionJob

### Design rules
- jobs must be idempotent
- avoid duplicate outbound responses
- session processing should lock per session
- webhook path must stay fast

---

## 17. Admin UI Specification Summary

The admin UI is desktop-first and operational.

### Core screens
1. Overview dashboard
2. Sessions index
3. Session detail / review
4. Flows index / editor
5. WhatsApp settings
6. Files
7. Team
8. Billing
9. Settings

### Most important screens
- Session detail / review
- Flow editor

### Core UI principles
- simple and calm
- operationally clear
- strong visual hierarchy
- easy staff review
- clear confidence and status indicators
- AI visible as assistive, not autonomous

---

## 18. Security and Compliance

This system handles sensitive patient-adjacent data.

### Minimum controls
- row-level tenant scoping by practice
- encrypted secrets/tokens
- private file storage
- signed file access
- RBAC for admin/staff
- audit trail for manual edits
- idempotent webhook handling
- secure background processing
- masked display of sensitive identifiers
- retention policy planning
- secure backups
- least-privilege IAM for S3 and infrastructure

### Sensitive UI behavior
- mask ID numbers by default where appropriate
- show file access through controlled actions
- make audit events visible for manual edits

---

## 19. Email / Notifications

### Completion email
When a session completes or reaches staff review:
- send summary email to configured recipients
- include patient/session identifiers
- include structured data summary
- include secure review link
- include attachment references where appropriate

### Internal alerts
Potential future alerts:
- failed delivery
- low-confidence extraction queue
- session stalled too long
- webhook disconnected

---

## 20. MVP Scope

### Included in MVP
- practice admin UI
- intake flow configuration
- WhatsApp-based intake session handling
- out-of-order information absorption
- secure attachment storage
- AI-assisted extraction
- AI-assisted reply phrasing
- staff review workspace
- completion summary email
- audit trail basics

### Explicitly excluded from MVP
- arbitrary PDF autofill engine
- digital signature workflows
- ERM integration
- advanced analytics
- complex permissions matrix
- multilingual intelligence beyond configured support
- fully autonomous AI agent logic

---

## 21. Post-MVP Roadmap Readiness

The architecture should be ready for:
- PDF autofill from canonical field keys
- patient consent documents and signatures
- ERM / practice management sync
- more intake flow types
- more document types
- richer review workflows
- derived patient master records later

---

## 22. Recommended Rails Project Structure

### Namespaces
- Admin::
- Whatsapp::
- AI::
- Attachments::
- Sessions::
- Fields::

### Example controllers
- Admin::DashboardController
- Admin::SessionsController
- Admin::FlowsController
- Admin::WhatsappController
- Admin::FilesController
- Admin::TeamMembersController
- Admin::BillingController
- Admin::SettingsController
- Webhooks::WhatsappController

### Example service objects
- Whatsapp::WebhookParser
- Whatsapp::SignatureVerifier
- Whatsapp::SendMessage
- Sessions::FindOrCreate
- Sessions::LockAndProcess
- Attachments::DownloadFromMeta
- Attachments::StoreToS3
- Attachments::RunExtraction
- Fields::ExtractCandidates
- Fields::ApplyCandidates
- Fields::ResolveBranches
- Fields::ComputeOutstanding
- Conversation::SelectNextAsk
- Conversation::GenerateReply
- Sessions::Complete
- Exports::BuildCompletionEmail

### Recommended UI components
- sidebar
- topbar
- status badge
- metric card
- data table
- field state row
- transcript bubble
- attachment card
- audit event list
- drawer/modal primitives

---

## 23. Build Order

### Phase 1
- Rails app shell
- authentication
- tenancy basics
- admin layout
- sessions index and detail with seeded data
- flows editor with seeded data

### Phase 2
- real models and associations
- intake flow persistence
- session/message persistence
- field value logic
- review workflow

### Phase 3
- WhatsApp Cloud API inbound/outbound
- media download
- S3 storage
- attachment metadata

### Phase 4
- AI extraction
- AI response generation
- confidence handling
- clarification flow

### Phase 5
- emails
- retries
- audit hardening
- production observability
- deployment

---

## 24. Key Non-Negotiables

1. Rails owns orchestration.
2. AI never owns truth.
3. The system is field-based, not script-step-based.
4. Out-of-order absorption is mandatory.
5. Human review is a first-class workflow.
6. Security and auditability are part of the product, not cleanup work.
7. Session completion is computed from resolved required fields.
8. The admin UX must stay simple enough for real medical staff.

---

## 25. Final Technical Position

MediComm should be built as a structured intake platform with a conversational front end.

The correct architecture is:
- deterministic engine underneath
- AI phrasing and extraction around it
- secure file handling
- strong staff review tools
- clean Rails admin UI
- future-proof domain model

If this foundation is built correctly, later features such as PDF autofill, signatures, and ERM sync become extensions instead of rewrites.
