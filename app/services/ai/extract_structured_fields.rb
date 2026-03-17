module AI
  class ExtractStructuredFields
    def self.call(prompt:, schema:)
      new(prompt: prompt, schema: schema).call
    end

    def initialize(prompt:, schema:)
      @prompt = prompt
      @schema = schema
    end

    def call
      # TODO: Call AI provider for structured extraction with confidence metadata.
      []
    end
  end
end
