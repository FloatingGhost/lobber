import Config

config :lobber, Lobber.Provider.OpenRouter, api_key: System.get_env("OPENROUTER_API_KEY")

config :lobber, Lobber.Provider.Xiaomi, api_key: System.get_env("XIAOMI_API_KEY")

config :lobber, Lobber.Channels.Discord, bot_token: System.get_env("DISCORD_BOT_TOKEN")

config :lobber, Lobber.Integrations.Perplexity, api_key: System.get_env("PERPLEXITY_API_KEY")
