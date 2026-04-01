import Config

config :logger,
  level: :info

config :tesla,
  adapter: {
    Tesla.Adapter.Gun,
    timeout: 120_000
  }

config :lobber,
  cave: ".lobber/",
  provider: Lobber.Provider.Xiaomi,
  channels: [
    Lobber.Channels.Discord
  ]

config :lobber, Lobber.Provider.OpenRouter,
  model_id: "xiaomi/mimo-v2-pro",
  api_key: System.get_env("OPENROUTER_API_KEY")

config :lobber, Lobber.Provider.Xiaomi,
  model_id: "mimo-v2-pro",
  api_key: System.get_env("XIAOMI_API_KEY")

config :lobber, Lobber.Channels.Discord, bot_token: System.get_env("DISCORD_BOT_TOKEN")

config :lobber, Lobber.Integrations.Perplexity,
  api_key: System.get_env("PERPLEXITY_API_KEY"),
  sonar_model: "sonar-pro"

config :lobber, Lobber.Tasks.Scheduler, storage: Lobber.Tasks.CaveStorage

if File.exists?("./config/#{Mix.env()}.config.exs") do
  import_config "#{Mix.env()}.config.exs"
end
