import Config

config :logger,
  level: :all

config :lobber,
  cave: ".lobber/"

config :lobber, Lobber.Routing,
  default: [provider: Lobber.Provider.Xiaomi, model_id: "xiaomi/mimo-v2-flash"],
  conversation_compaction: [provider: Lobber.Provider.Xiaomi, model_id: "xiaomi/mimo-v2-flash"]

if File.exists?("./config/dev.secret.exs") do
  import_config "dev.secret.exs"
end
