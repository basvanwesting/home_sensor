defmodule HomeSensor.Configurator do
  @behaviour NervesHubLink.Configurator

  require Logger
  alias NervesHubLink.Certificate

  @impl true
  def build(config) do
    priv_dir = Application.app_dir(:home_sensor, "priv")
    certfile = Path.join(priv_dir, "9794.cert")
    keyfile = Path.join(priv_dir, "9794.key")

    signer =
      Path.join(priv_dir, "nerveskey_prod_signer1.cert")
      |> File.read!()

    update_config(config, certfile, keyfile, signer)
  end

  defp build_cacerts(signer) do
    signer_der = Certificate.pem_to_der(signer)

    [signer_der | NervesHubLink.Certificate.ca_certs()]
  end

  defp update_config(config, certfile, keyfile, signer) do
    ssl =
      config.ssl
      |> Keyword.put(:certfile, certfile)
      |> Keyword.put(:keyfile, keyfile)
      |> Keyword.put(:cacerts, build_cacerts(signer))

    socket = Keyword.put(config.socket, :reconnect_interval, 15000)

    Logger.info("NervesHubLink config.ssl: #{inspect ssl}")

    %{config | socket: socket, ssl: ssl}
  end

  defp to_der(file) do
    File.read!(file)
    |> Certificate.pem_to_der()
  end
end
