defmodule HomeSensor.Sensors.SGP30 do
  @moduledoc false

  use GenServer
  #require Logger

  alias HomeSensor.Measurement

  @i2c Circuits.I2C
  @i2c_bus "i2c-1"
  @i2c_retry_count 2

  @address 0x58

  @get_serial_id_cmd            <<0x3682::16>>
  @get_serial_id_bytes          9
  @init_air_quality_cmd         <<0x2003::16>>
  @init_air_quality_delay       5000
  @measure_air_quality_cmd      <<0x2008::16>>
  @measure_air_quality_bytes    6
  @measure_air_quality_duration 12
  @measure_air_quality_interval 1000

  defmodule State do
    @moduledoc false
    defstruct \
      state:    :disconnected, \
      i2c_ref:  nil,           \
      eco2_ppm: nil,           \
      tvoc_ppb: nil
  end

  def start_link(_args) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_args) do
    {:ok, %State{}, {:continue, :connect}}
  end

  def handle_continue(:connect, %State{state: :disconnected} = state) do
    with {:ok, i2c_ref} <- @i2c.open(@i2c_bus),
         true <- detect_device(i2c_ref) do
      Process.send_after(self(), :init_air_quality, @init_air_quality_delay)
      {:noreply, %{state | state: :initializing, i2c_ref: i2c_ref}}
    else
      false -> {:noreply, state}
    end
  end

  def handle_info(:init_air_quality, %State{state: :initializing} = state) do
    with :ok <- @i2c.write(state.i2c_ref, @address, @init_air_quality_cmd, retries: @i2c_retry_count) do
      Process.send_after(self(), :measure_air_quality, @measure_air_quality_interval)
      {:noreply, %{state | state: :active}}
    end
  end

  def handle_info(:measure_air_quality, %State{state: :active} = state) do
    with :ok <- @i2c.write(state.i2c_ref, @address, @measure_air_quality_cmd, retries: @i2c_retry_count) do
      Process.send_after(self(), :read_air_quality, @measure_air_quality_duration)
      {:noreply, state}
    end
  end

  def handle_info(:read_air_quality, %State{state: :active} = state) do
    with {:ok, reply} <- @i2c.read(state.i2c_ref, @address, @measure_air_quality_bytes, retries: @i2c_retry_count) do
      <<eco2_ppm::16, _eco2_ppm_crc::8, tvoc_ppb::16, _tvoc_ppb_crc::8>> = reply
      Process.send_after(self(), :measure_air_quality, @measure_air_quality_interval - @measure_air_quality_duration)
      {:noreply, %{state | eco2_ppm: eco2_ppm, tvoc_ppb: tvoc_ppb}}
    end
  end

  def handle_call(:get_measurements, _from, %State{state: :active} = state) do
    measurements = [
      %Measurement{
        sensor: "SGP30",
        quantity: "eCO2",
        value: state.eco2_ppm,
        unit: "ppm",
      },
      %Measurement{
        sensor: "SGP30",
        quantity: "TVOC",
        value: state.tvoc_ppb,
        unit: "ppb",
      },
    ]

    {:reply, measurements, state}
  end
  def handle_call(:get_measurements, _from, state) do
    {:reply, [], state}
  end

  def get_measurements() do
    GenServer.call(__MODULE__, :get_measurements)
  end

  def detect_device(i2c_ref) do
    with :ok <- @i2c.write(i2c_ref, @address, @get_serial_id_cmd, retries: @i2c_retry_count),
         {:ok, _reply} <- @i2c.read(i2c_ref, @address, @get_serial_id_bytes, retries: @i2c_retry_count) do
      true
    else
      {:error, :i2c_nak} -> false
    end
  end

end
