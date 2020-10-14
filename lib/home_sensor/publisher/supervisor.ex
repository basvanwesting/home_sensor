defmodule HomeSensor.Publisher.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link(_args) do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children = [
      {HomeSensor.Publisher.AMQP, []},
      {HomeSensor.Publisher.Producer, []},
      {HomeSensor.Publisher.Consumer, []},
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
