import Config

config :logger,
  level: :all

config :lobber,
  cave: ".lobber/",
  provider: Lobber.Provider.OpenRouter

config :lobber, Lobber.Provider.OpenRouter, model_id: "xiaomi/mimo-v2-flash"

if File.exists?("./config/dev.secret.exs") do
  import_config "dev.secret.exs"
end
