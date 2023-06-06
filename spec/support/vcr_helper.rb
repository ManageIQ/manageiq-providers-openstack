def fix_token_expires_at_interaction(interaction)
  return unless interaction.request.uri.end_with?("v3/auth/tokens")

  data = JSON.parse(interaction.response.body)
  return if data.dig("token", "expires_at").nil?

  data["token"]["expires_at"] = "9999-12-31T23:59:59.999999Z"
  interaction.response.body = data.to_json.force_encoding('ASCII-8BIT')
end

def fix_token_expires_at(config)
  config.before_record { |interaction| fix_token_expires_at_interaction(interaction) }
end
