def fix_token_expires_at(interaction)
  data = JSON.parse(interaction.response.body)
  data["token"]["expires_at"] = "9999-12-31T23:59:59.999999Z"
  interaction.response.body = data.to_json.force_encoding('ASCII-8BIT')
end
