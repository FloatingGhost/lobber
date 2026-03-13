import Config

config :tesla, adapter: Tesla.Adapter.Mint

config :lobber,
  discord_bot_token: System.get_env("DISCORD_BOT_TOKEN"),
  api_key: System.get_env("OPENROUTER_API_KEY")
