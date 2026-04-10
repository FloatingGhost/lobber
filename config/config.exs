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
  channels: [
    Lobber.Channels.Discord
  ]

config :lobber, Lobber.Conversation,
  compaction_threshold: 50_000,
  # how many user-agent turns should be kept?
  leg_retention: 2

config :lobber, Lobber.Routing,
  default: [provider: Lobber.Provider.Xiaomi, model_id: "xiaomi/mimo-v2-pro"],
  conversation_compaction: [provider: Lobber.Provider.Xiaomi, model_id: "xiaomi/mimo-v2-flash"]

config :lobber, Lobber.Provider.OpenRouter, api_key: System.get_env("OPENROUTER_API_KEY")

config :lobber, Lobber.Provider.Xiaomi,
  api_key: System.get_env("XIAOMI_API_KEY"),
  type: :standard,
  image_model: "mimo-v2-omni"

config :lobber, Lobber.Channels.Discord, bot_token: System.get_env("DISCORD_BOT_TOKEN")

config :lobber, Lobber.Integrations.Perplexity,
  api_key: System.get_env("PERPLEXITY_API_KEY"),
  sonar_model: "sonar-pro"

config :lobber, Lobber.Tasks.Scheduler, storage: Lobber.Tasks.CaveStorage

config :nanoid,
  size: 10,
  alphabet: "0123456789abcdefghijklmnopqrstuvwxyz"

if File.exists?("./config/#{Mix.env()}.config.exs") do
  import_config "#{Mix.env()}.config.exs"
end
