OpenAI.configure do |config|
  config.access_token = ENV.fetch("OPENAI_API_KEY") # Use fetch to raise an error if the key is not set
end
