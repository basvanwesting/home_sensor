defmodule HomeSensor.Sensors.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link(_args) do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children = [
      {HomeSensor.Sensors.SGP30, []},
      {HomeSensor.Sensors.SCD30, []},
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
