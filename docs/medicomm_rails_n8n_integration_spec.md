# MediComm Rails Implementation for n8n-Orchestrated Conversation Flow

## Purpose

This document defines the **Rails-side implementation required** for the MediComm WhatsApp conversation pipeline when using **n8n as an external AI conversation worker**.

In this architecture:

- Meta sends inbound WhatsApp webhook events to Rails
- Rails persists and owns all business state
- Rails triggers n8n via webhook
- n8n fetches conversation state from Rails
- n8n proposes field captures and reply text
- Rails validates, persists, and sends the WhatsApp reply

Rails remains the **source of truth** at all times.

---

## 1. Core Responsibility Boundary

### Rails owns
- session creation and lookup
- intake flow schema
- field definitions
- field completion state
- allowed next asks
- message persistence
- attachment persistence
- audit trail
- validation and normalization
- outbound WhatsApp sending
- session completion logic

### n8n owns
- AI orchestration
- extracting candidate field values from message context
- proposing natural-language replies

### Critical rule
n8n must never become the owner of:
- session state
- required field logic
- completion logic
- direct WhatsApp sending
- direct database mutation

---

## 2. High-Level Runtime Flow

```text
Meta → Rails webhook
→ ProcessIncomingWhatsappWebhookJob
→ find/create intake session
→ persist inbound message
→ trigger n8n webhook with session_id
→ n8n fetches Rails conversation state
→ n8n runs AI agent
→ n8n posts structured response back to Rails
→ Rails validates/applies response
→ Rails sends WhatsApp reply
→ Rails persists outbound message
```

---

## 3. Rails Endpoints Required

## 3.1 Meta inbound webhook
### Endpoint
- `POST /webhooks/whatsapp`

### Responsibility
- receive raw inbound WhatsApp events from Meta
- verify signature
- resolve `WhatsappAccount`
- enqueue processing job
- return quickly with accepted response

### Notes
This controller should remain thin.
It should not:
- create field values
- decide reply text
- send outbound messages directly

---

## 3.2 n8n conversation state endpoint
### Endpoint
- `GET /api/v1/intake_sessions/:id/conversation_state`

### Responsibility
Expose the current Rails-owned session state so n8n can reason from a clean structured payload.

### Required response data
- session metadata
- flow metadata
- completed fields
- missing required fields
- clarification-needed fields
- allowed next asks
- latest message
- recent transcript
- instructions/guardrails

### Example response
```json
{
  "session": {
    "id": 123,
    "status": "active",
    "patient_phone_e164": "+27825608530",
    "language": "en"
  },
  "flow": {
    "id": 7,
    "name": "New Patient Intake",
    "tone_preset": "warm_professional"
  },
  "state": {
    "completed_fields": [
      { "key": "patient_full_name", "value": "Karel Nel" }
    ],
    "missing_fields": [
      "patient_id_number",
      "medical_aid_name"
    ],
    "needs_clarification": [],
    "allowed_next_asks": [
      "patient_id_number",
      "medical_aid_name"
    ]
  },
  "latest_message": {
    "provider_message_id": "wamid....",
    "type": "text",
    "text": "Hi"
  },
  "recent_transcript": [
    { "direction": "inbound", "text": "Hi" }
  ],
  "instructions": {
    "do_not_ask_completed_fields": true,
    "do_not_change_business_rules": true,
    "reply_naturally": true
  }
}
```

---

## 3.3 n8n conversation response endpoint
### Endpoint
- `POST /api/v1/intake_sessions/:id/conversation_response`

### Responsibility
Receive n8n’s proposed candidate field values and proposed reply text.

### Expected payload
```json
{
  "source_message_id": "wamid....",
  "candidate_fields": [
    {
      "key": "patient_full_name",
      "value": "Karel Nel",
      "confidence": 0.97,
      "source": "message_text"
    }
  ],
  "clarifications": [],
  "reply": {
    "text": "Thank you. Please send your ID number so we can continue."
  }
}
```

### Rails must then
- validate field keys against active flow
- validate values and normalize where needed
- persist `IntakeFieldValue` changes
- create `IntakeEvent` audit records
- recompute unresolved fields
- send WhatsApp reply if valid
- persist outbound message

---

## 3.4 Optional future endpoints
These are not required for MVP but may be useful later:
- `GET /api/v1/intake_flows/:id/schema`
- `GET /api/v1/intake_sessions/:id/transcript`
- `GET /api/v1/intake_sessions/:id/attachments`

For MVP, avoid overbuilding. The single conversation state endpoint is enough.

---

## 4. Rails Services Required

## 4.1 `Sessions::FindOrCreate`
### Responsibility
Find the currently open session for an incoming patient or create a new one.

### Suggested lookup keys
- practice
- whatsapp_account
- patient phone number (E.164)

### Suggested open statuses
- `pending_start`
- `active`
- `awaiting_patient`
- `processing`

---

## 4.2 `Whatsapp::PersistInboundMessage`
### Responsibility
Create an inbound `IntakeMessage` record from the Meta webhook payload.

### Must handle
- message type
- message body
- provider message id
- raw payload
- sender phone / wa_id
- timestamps
- idempotency

### Critical rule
Do not process the same provider message twice.

---

## 4.3 `Fields::ComputeOutstanding`
### Responsibility
Compute the live intake state for the session.

### Must return
- completed fields
- missing required fields
- clarification-needed fields
- allowed next asks

This service is the backbone of the hybrid Rails + n8n design.

---

## 4.4 `Conversation::BuildN8nRequest`
### Responsibility
Build the structured payload Rails uses when triggering n8n.

### Example minimal trigger payload
```json
{
  "session_id": 123,
  "practice_id": 4,
  "source_message_id": "wamid...."
}
```

If needed, Rails may also embed selected context directly, but the preferred pattern is:
- trigger n8n
- let n8n call Rails back for full state

---

## 4.5 `N8n::TriggerConversationAgent`
### Responsibility
Send the trigger webhook to n8n.

### Must handle
- HTTP POST to n8n webhook URL
- auth headers if needed
- retries or controlled failure logging
- timeout handling
- request/response logging

---

## 4.6 `Conversation::ApplyN8nResponse`
### Responsibility
Validate and persist the results returned by n8n.

### Must do
- verify the source session
- validate candidate field keys
- reject fields outside the active flow
- normalize and validate values
- create or supersede `IntakeFieldValue` records
- create `IntakeEvent` audit records
- decide whether reply is safe to send

### Must not do
- trust n8n blindly
- skip field validation
- accept arbitrary new field keys

---

## 4.7 `Whatsapp::SendMessage`
### Responsibility
Send the outbound reply via WhatsApp Cloud API.

### Must do
- call Meta Graph API
- handle provider response
- return provider message id / metadata
- raise or fail cleanly on delivery errors

### Important
Rails should send the final WhatsApp reply.
n8n should not send directly to Meta.

---

## 4.8 `Whatsapp::PersistOutboundMessage`
### Responsibility
Persist the outbound message as an `IntakeMessage` record after Rails sends the reply.

### Why
This keeps:
- transcript continuity
- auditability
- provider message tracking
- future delivery status handling

---

## 5. Rails Jobs Required

## 5.1 `ProcessIncomingWhatsappWebhookJob`
### Responsibility
Process each inbound WhatsApp event asynchronously.

### Flow
1. parse message
2. find or create session
3. persist inbound message
4. trigger n8n webhook with session reference

### Important
This job should not attempt to decide replies itself.

---

## 5.2 `ApplyN8nConversationResponseJob`
### Responsibility
Handle n8n callback responses asynchronously.

### Flow
1. receive callback payload
2. validate payload
3. apply candidate fields
4. recompute state if needed
5. send WhatsApp reply
6. persist outbound message

You may process synchronously at first if very small, but job-based handling is cleaner and more resilient.

---

## 6. Rails Controllers Required

## 6.1 `Webhooks::WhatsappController`
### Responsibility
Handle Meta inbound webhooks only.

### Notes
Keep it thin and idempotent.

---

## 6.2 `Api::V1::IntakeSessionsController`
### Responsibility
Expose session conversation state for n8n.

### Suggested actions
- `conversation_state`

---

## 6.3 `Api::V1::ConversationResponsesController`
### Responsibility
Receive structured n8n callback payloads.

### Suggested action
- `create`

---

## 7. Authentication and Security for n8n-Facing Endpoints

n8n-facing Rails endpoints must not be publicly open.

### Recommended protections
- Bearer token auth
- or HMAC signature validation
- request logging
- session ownership checks
- strict session lookup scoped correctly

### Minimum MVP recommendation
Use a shared Bearer token in request headers for:
- fetching conversation state
- posting conversation response

---

## 8. Required Data Behavior in Rails

## 8.1 Session lookup
Rails must always determine the active session.
n8n must not infer session identity from transcript alone.

---

## 8.2 Field truth
Rails must always determine:
- which fields exist
- which fields are complete
- which fields are unresolved
- which next asks are permitted

n8n only receives this state and proposes changes.

---

## 8.3 Idempotency
Rails must never send duplicate replies for the same inbound Meta message.

### Minimum mechanism
- unique provider message id
- skip processing if already persisted
- optionally log duplicate receipt event

---

## 8.4 Allowed field whitelist
Rails must reject candidate field keys that do not exist in the active intake flow.

---

## 8.5 Reply validation
Rails should enforce:
- non-empty reply
- acceptable max length
- string format sanity
- safe fallback if n8n output is empty or broken

### Suggested fallback
```text
Thank you, we received your message and will continue shortly.
```

---

## 9. Suggested Routes

```ruby
namespace :webhooks do
  resource :whatsapp, only: [:show, :create]
end

namespace :api do
  namespace :v1 do
    resources :intake_sessions, only: [] do
      member do
        get :conversation_state
        post :conversation_response
      end
    end
  end
end
```

---

## 10. Suggested Request/Response Lifecycle

### Inbound
```text
Meta webhook
→ Webhooks::WhatsappController#create
→ ProcessIncomingWhatsappWebhookJob
→ Sessions::FindOrCreate
→ Whatsapp::PersistInboundMessage
→ N8n::TriggerConversationAgent
```

### n8n fetches state
```text
n8n
→ GET /api/v1/intake_sessions/:id/conversation_state
```

### n8n posts response
```text
n8n
→ POST /api/v1/intake_sessions/:id/conversation_response
→ Conversation::ApplyN8nResponse
→ Whatsapp::SendMessage
→ Whatsapp::PersistOutboundMessage
```

---

## 11. Recommended Rails Implementation Order

### Step 1
Finish inbound webhook persistence:
- session lookup
- inbound message storage
- idempotency

### Step 2
Implement `conversation_state` endpoint

### Step 3
Implement n8n trigger service

### Step 4
Implement `conversation_response` endpoint

### Step 5
Implement response application logic

### Step 6
Implement outbound WhatsApp sending and outbound message persistence

---

## 12. Minimal Acceptance Criteria

Rails-side implementation is ready for the first real loop when:

- Meta webhook is received and accepted
- inbound message is persisted
- session is found or created
- n8n can fetch conversation state from Rails
- n8n can post candidate fields + reply back to Rails
- Rails validates and persists the result
- Rails sends the reply through WhatsApp Cloud API
- outbound message is persisted
- duplicate inbound messages do not create duplicate replies

---

## 13. Final Architectural Position

Rails is the system of record.

Even with n8n in the loop:
- Rails owns correctness
- Rails owns state
- Rails owns auditability
- Rails owns delivery

n8n is an AI conversation worker, not the application core.

That distinction is what keeps MediComm stable as it grows.
