defmodule HomeSensor.Configurator do
  @behaviour NervesHubLink.Configurator

  require Logger

  @impl true
  def build(config) do
    Logger.info("NervesHubLink config: #{inspect config}")

    priv_dir = Application.app_dir(:home_sensor, "priv")
    certfile = Path.join(priv_dir, "9794-cert.pem")
    keyfile = Path.join(priv_dir, "9794-key.pem")
    File.exists?(certfile) || raise "certfile cannot by found: #{certfile}"
    File.exists?(keyfile)  || raise "keyfile cannot by found: #{keyfile}"

    ssl =
      config.ssl
      |> Keyword.put(:certfile, certfile)
      |> Keyword.put(:keyfile, keyfile)

    %{config | ssl: ssl}
  end
end
