import Config

config :lobber, Lobber.Provider.OpenRouter,
  api_key: System.fetch_env!("OPENROUTER_API_KEY")

config :lobber, Lobber.Channels.Discord,
  bot_token: System.fetch_env!("DISCORD_BOT_TOKEN")

config :lobber, Lobber.Integrations.Perplexity,
  api_key: System.get_env("PERPLEXITY_API_KEY")
