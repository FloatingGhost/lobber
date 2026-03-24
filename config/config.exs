import Config

config :tesla, adapter: Tesla.Adapter.Mint

config :lobber,
  cave: ".lobber/",
  provider: Lobber.Provider.OpenRouter,
  channels: [
    Lobber.Channels.Discord
  ]

config :lobber, Lobber.Provider.OpenRouter,
  model_id: "xiaomi/mimo-v2-pro",
  api_key: System.get_env("OPENROUTER_API_KEY")

config :lobber, Lobber.Channels.Discord, bot_token: System.get_env("DISCORD_BOT_TOKEN")
