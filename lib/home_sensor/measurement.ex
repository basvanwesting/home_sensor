defmodule HomeSensor.Measurement do
  @moduledoc false

  @derive Jason.Encoder
  defstruct \
    measured_at: nil, \
    quantity:    nil, \
    unit:        nil, \
    value:       nil, \
    host:        nil, \
    sensor:      nil, \
    location:    nil

end
