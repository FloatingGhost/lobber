import Config

config :tesla, adapter: Tesla.Adapter.Mint

config :lobber,
  soul_directory: ".lobber/",
  provider: Lobber.Provider.OpenRouter,
  model_id: "qwen/qwen3-32b",
  discord_bot_token: System.get_env("DISCORD_BOT_TOKEN"),
  openrouter_api_key: System.get_env("OPENROUTER_API_KEY")
