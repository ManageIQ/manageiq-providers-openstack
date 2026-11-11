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

def replace_header_values(headers, header_name, value)
  headers.each do |name, values|
    next unless name.casecmp?(header_name)

    values.map! { value }
  end
end

def filter_subject_token_interaction(interaction)
  replace_header_values(interaction.response.headers, "X-Subject-Token", "KEYSTONE_TOKEN_ID")
  replace_header_values(interaction.request.headers, "X-Auth-Token", "KEYSTONE_TOKEN_ID")
end

def filter_subject_token(config)
  config.before_record { |interaction| filter_subject_token_interaction(interaction) }
end
