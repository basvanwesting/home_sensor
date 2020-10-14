defmodule HomeSensor.Publisher.Consumer do
  use GenStage
  require Logger
  use AMQP

  @reconnect_interval 10_000

  defmodule State do
    @moduledoc false
    defstruct queue: nil, chan: nil
  end

  def start_link(_args) do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    send(self(), :connect)
    {:consumer, %State{}}
  end

  def handle_info(:connect, state) do
    with {:ok, queue} <- Application.fetch_env(:amqp, :sensor_measurements_queue),
         {:ok, conn} <- HomeSensor.Publisher.AMQP.get_connection(),
         {:ok, chan} <- Channel.open(conn),
         :ok <- GenStage.async_subscribe(__MODULE__, to: HomeSensor.Publisher.Producer, max_demand: 1) do

      Process.monitor(chan.pid)
      {:noreply, [], %{state | queue: queue, chan: chan}}
    else
      error ->
        Logger.error("Failed to connect: #{inspect error}. Reconnecting later...")
        Process.send_after(self(), :connect, @reconnect_interval)
        {:noreply, [], nil}
    end
  end

  def handle_info({:DOWN, _, :process, _pid, reason}, _) do
    # Stop GenServer. Will be restarted by Supervisor.
    Logger.error("Channel went down")
    {:stop, {:connection_lost, reason}, nil}
  end

  def handle_events([event], _from, state) do
    Logger.info("publishing #{event}")
    AMQP.Basic.publish(state.chan, state.queue, "", event)

    {:noreply, [], state}
  end
end
