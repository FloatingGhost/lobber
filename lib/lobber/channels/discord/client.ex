defmodule Lobber.Channels.Discord.Client do
  @discord "https://discord.com"

  def bot_token do
    Lobber.Config.get(Lobber.Channels.Discord, :bot_token)
  end

  def client() do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, @discord},
      {Tesla.Middleware.Headers, [{"content-type", "application/json"} | headers()]},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Timeout, timeout: 10_000}
    ])
  end

  def headers do
    [
      {"user-agent", "YuiBot (application 182675940042735616)"},
      {"authorization", "Bot #{bot_token()}"}
    ]
  end
end
