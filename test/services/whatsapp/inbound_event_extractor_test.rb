require "test_helper"

class Whatsapp::InboundEventExtractorTest < ActiveSupport::TestCase
  test "extracts media attachment metadata from media messages" do
    parsed_event = {
      entries: [
        {
          "changes" => [
            {
              "field" => "messages",
              "value" => {
                "metadata" => {
                  "phone_number_id" => "155512340001",
                  "display_phone_number" => "155512340001"
                },
                "contacts" => [
                  {
                    "profile" => { "name" => "Media Patient" }
                  }
                ],
                "messages" => [
                  {
                    "from" => "27825550123",
                    "id" => "wamid-media-001",
                    "timestamp" => Time.current.to_i.to_s,
                    "type" => "document",
                    "document" => {
                      "id" => "meta-doc-001",
                      "mime_type" => "application/pdf",
                      "filename" => "identity.pdf",
                      "caption" => "ID copy"
                    }
                  }
                ]
              }
            }
          ]
        }
      ]
    }

    result = Whatsapp::InboundEventExtractor.call(parsed_event: parsed_event)

    assert_equal 1, result.size
    extracted_message = result.first
    assert_equal "document", extracted_message[:message_type]
    assert_equal "Media Patient", extracted_message[:patient_display_name]

    attachments = extracted_message[:attachments]
    assert_equal 1, attachments.size
    assert_equal "meta-doc-001", attachments.first[:media_id]
    assert_equal "application/pdf", attachments.first[:mime_type]
    assert_equal "identity.pdf", attachments.first[:file_name]
  end
end
