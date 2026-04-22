# WhatsApp Follow-up Template (Meta)

Use this for the admin **Request Follow-up** action.

## Template Identifier

- `template_name` (template id in app env): `medicomm_follow_up_v20260422_01`
- `language`: `en`
- `category`: `UTILITY`

## Template Body Text

```text
Hi {{1}}, we still need a few details to complete your intake.
Please reply to continue.
```

## Parameter Mapping

1. `{{1}}` -> patient display name

## WhatsApp Cloud API Payload Structure

```json
{
  "messaging_product": "whatsapp",
  "recipient_type": "individual",
  "to": "2782XXXXXXX",
  "type": "template",
  "template": {
    "name": "medicomm_follow_up_v20260422_01",
    "language": {
      "code": "en"
    },
    "components": [
      {
        "type": "body",
        "parameters": [
          { "type": "text", "text": "Karel Nel" }
        ]
      }
    ]
  }
}
```
