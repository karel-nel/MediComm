module AI
  class GenerateReply
    def self.call(context:, style:)
      new(context: context, style: style).call
    end

    def initialize(context:, style:)
      @context = context
      @style = style
    end

    def call
      # TODO: Call AI provider to generate concise patient-facing reply text.
      nil
    end
  end
end
