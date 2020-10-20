defmodule HomeSensor.Sensors.SCD30 do
  @moduledoc false

  use GenServer
  require Logger

  alias HomeSensor.Measurement

  @i2c Circuits.I2C
  @i2c_bus "i2c-1"
  @i2c_retry_count 2

  @address 0x61

  @read_serialnr_cmd              <<0xd033::16>>
  @read_serialnr_bytes            9
  @set_measurement_interval_cmd   <<0x4600::16>>
  @set_measurement_interval_value 2000
  @set_measurement_interval_delay 5000
  @get_data_ready_cmd             <<0x0202::16>>
  @get_data_ready_bytes           3
  @read_measurement_cmd           <<0x0300::16>>
  @read_measurement_bytes         18

  @crc_options %{
    width: 8,
    poly: 0x31, # P(x) = x^8 + x^5 + x^4 + 1 = 100110001
    init: 0xff,
    refin: false,
    refout: false,
    xorout: 0x00
  }

  defmodule State do
    @moduledoc false
    defstruct \
      state:               :disconnected, \
      i2c_ref:             nil,  \
      co2_ppm:             nil,  \
      temperature_celsius: nil,  \
      humidity_percent:    nil
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
      Process.send_after(self(), :set_measurement_interval, @set_measurement_interval_delay)
      {:noreply, %{state | state: :initializing, i2c_ref: i2c_ref}}
    else
      false -> {:noreply, state}
    end
  end

  def handle_info(:set_measurement_interval, %State{state: :initializing} = state) do
    message = build_message(
      @set_measurement_interval_cmd,
      ceil(@set_measurement_interval_value/1000)
    )
    with :ok <- @i2c.write(state.i2c_ref, @address, message, retries: @i2c_retry_count) do
      Process.send_after(self(), :measure, @set_measurement_interval_value)
      {:noreply, %{state | state: :active}}
    end
  end

  def handle_info(:measure, %State{state: :active} = state) do
    with true <- measurement_ready?(state.i2c_ref),
         %{} = data <- read_measurement(state.i2c_ref) do

       Process.send_after(self(), :measure, @set_measurement_interval_value)
       {:noreply, struct(state, data)}
    else
      false ->
        Process.send_after(self(), :measure, @set_measurement_interval_value)
        {:noreply, state}
    end
  end

  def measurement_ready?(i2c_ref) do
    with :ok <- @i2c.write(i2c_ref, @address, @get_data_ready_cmd, retries: @i2c_retry_count),
         {:ok, reply} <- @i2c.read(i2c_ref, @address, @get_data_ready_bytes, retries: @i2c_retry_count),
         true <- parse_get_data_ready(reply) do
      true
    else
      _ ->
        Logger.warn("SCD30 measurement not ready!")
        false
    end
  end

  def read_measurement(i2c_ref) do
    with :ok <- @i2c.write(i2c_ref, @address, @read_measurement_cmd, retries: @i2c_retry_count),
         {:ok, reply} <- @i2c.read(i2c_ref, @address, @read_measurement_bytes, retries: @i2c_retry_count),
          %{} = data <- parse_read_measurement(reply) do
      data
    else
      error ->
        Logger.error("SCD30 read_measurement error: #{inspect error}. Propagating error!")
        raise error
    end
  end

  def detect_device(i2c_ref) do
    with :ok <- @i2c.write(i2c_ref, @address, @read_serialnr_cmd, retries: @i2c_retry_count),
         {:ok, _reply} <- @i2c.read(i2c_ref, @address, @read_serialnr_bytes, retries: @i2c_retry_count) do
      true
    else
      {:error, :i2c_nak} -> false
    end
  end

  def handle_call(:get_measurements, _from, %State{state: :active} = state) do
    measurements = [
      %Measurement{
        sensor: "SCD30",
        quantity: "CO2",
        value: state.co2_ppm,
        unit: "ppm",
      },
      %Measurement{
        sensor: "SCD30",
        quantity: "Temperature",
        value: state.temperature_celsius,
        unit: "Celcius",
      },
      %Measurement{
        sensor: "SCD30",
        quantity: "Humidity",
        value: state.humidity_percent,
        unit: "%",
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

  def build_message(command, value) when is_binary(command) and is_integer(value) do
    command <> <<value::16>> <> calculate_crc(value)
  end

  def parse_get_data_ready(value) when is_binary(value) do
    <<xsb::binary-size(2), crc_xsb::binary-size(1)>> = value
    if valid_crc?(xsb, crc_xsb) do
      <<result::16>> = xsb
      result == 1
    else
      nil #{:error, :invalid_crc}
    end
  end

  def parse_read_measurement(bytes) when is_binary(bytes) do
    <<co2_ppm_bytes::binary-size(6), temperature_bytes::binary-size(6), humidity_bytes::binary-size(6)>> = bytes

    %{
      co2_ppm:             convert_single_measurement_bytes_to_float(co2_ppm_bytes),
      temperature_celsius: convert_single_measurement_bytes_to_float(temperature_bytes),
      humidity_percent:    convert_single_measurement_bytes_to_float(humidity_bytes),
    }
  end

  def convert_single_measurement_bytes_to_float(value) when is_binary(value) do
    <<mxsb::binary-size(2), crc_mxsb::binary-size(1), lxsb::binary-size(2), crc_lxsb::binary-size(1)>> = value
    if valid_crc?(mxsb, crc_mxsb) && valid_crc?(lxsb, crc_lxsb) do
      <<result::float-signed-32>> = mxsb <> lxsb
      result
    else
      nil #{:error, :invalid_crc}
    end
  end

  def calculate_crc(value) when is_integer(value)  do
    calculate_crc(<<value::16>>)
  end
  def calculate_crc(value) when is_binary(value)  do
    <<CRC.calculate(value, @crc_options)>>
  end

  def valid_crc?(value, crc) when is_binary(crc) do
    calculate_crc(value) == crc
  end

end
