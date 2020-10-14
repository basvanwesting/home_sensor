defmodule HomeSensor.Publisher.AMQP do
  use GenServer
  require Logger
  alias AMQP.Connection

  @reconnect_interval 10_000

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    send(self(), :connect)
    {:ok, nil}
  end

  def get_connection do
    case GenServer.call(__MODULE__, :get) do
      nil -> {:error, :not_connected}
      conn -> {:ok, conn}
    end
  end

  def handle_call(:get, _, conn) do
    {:reply, conn, conn}
  end

  def handle_info(:connect, _conn) do
    connection_options = Application.fetch_env!(:amqp, :connection_options)
    case Connection.open(connection_options) do
      {:ok, conn} ->
        # Get notifications when the connection goes down
        Process.monitor(conn.pid)
        {:noreply, conn}

      {:error, reason} ->
        Logger.error("Failed to connect to AMQP: #{inspect reason}. Reconnecting later...")
        # Retry later
        Process.send_after(self(), :connect, @reconnect_interval)
        {:noreply, nil}
    end
  end

  def handle_info({:DOWN, _, :process, _pid, reason}, _) do
    # Stop GenServer. Will be restarted by Supervisor.
    {:stop, {:connection_lost, reason}, nil}
  end
end
