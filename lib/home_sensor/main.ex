defmodule HomeSensor.Main do
  @moduledoc false

  @default_interval 60_000 #ms

  alias HomeSensor.Sensors.SCD30
  alias HomeSensor.Sensors.SGP30
  alias HomeSensor.Publisher.Producer

  use GenServer

  defmodule State do
    @moduledoc false
    defstruct \
    interval: nil, \
    host: nil
  end

  def start_link(interval \\ @default_interval) do
    GenServer.start_link(__MODULE__, interval, name: __MODULE__)
  end

  def init(interval) do
    Process.send_after(self(), :tick, interval)
    {:ok, %State{interval: interval, host: get_hostname}}
  end

  def get_hostname() do
    {:ok, host} = :inet.gethostname()
    :erlang.iolist_to_binary(host)
  end

  def handle_info(:tick, state) do
    publish_measurements_for(SCD30, state.host)
    #publish_measurements_for(SGP30, state.host)

    Process.send_after(self(), :tick, state.interval)
    {:noreply, state}
  end

  def publish_measurements_for(sensor, host) do
    with measurements when is_list(measurements) <- sensor.get_measurements() do
      for measurement <- measurements do
        measurement
        |> enrich_measurement(host)
        |> Producer.enqueue
      end
    end
  end

  def enrich_measurement(measurement, host) do
    %{ measurement |
        measured_at: DateTime.now!("Etc/UTC"),
        host: host,
    }
  end

end

