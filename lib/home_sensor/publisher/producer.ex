defmodule HomeSensor.Publisher.Producer do
  use GenStage
  require Logger

  alias HomeSensor.Measurement

  def start_link(_args) do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:producer, :ok, buffer_size: 10_000}
  end

  def handle_call({:enqueue, event}, _from, state) do
    {:reply, :ok, [event], state} # Dispatch immediately
  end

  def handle_demand(demand, state) do
    Logger.info("handle_demand(#{inspect demand}, #{inspect state}) called")
    {:noreply, [], state} # We don't care about the demand
  end

  def enqueue(%Measurement{} = measurement) do
    event = Jason.encode!(measurement)
    GenServer.call(__MODULE__, {:enqueue, event})
  end
end

