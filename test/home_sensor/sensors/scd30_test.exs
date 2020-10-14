defmodule HomeSensor.Sensors.SCD30Test do
  use ExUnit.Case
  alias HomeSensor.Sensors.SCD30

  #doctest SCD30

  test "calculate_crc/1" do
    assert SCD30.calculate_crc(<<0xBEEF::16>>)       == <<0x92>>
    assert SCD30.calculate_crc(<<0xBE::8, 0xEF::8>>) == <<0x92>>

    assert SCD30.calculate_crc(0xBEEF)               == <<0x92>>
    assert SCD30.calculate_crc(48879)                == <<0x92>>
  end

  test "valid_crc?/2" do
    assert SCD30.valid_crc?(<<0xBEEF::16>>, <<0x92>>)
    assert SCD30.valid_crc?(<<0xBE::8, 0xEF::8>>, <<0x92>>)
  end

  test "build_message/2" do
    message = SCD30.build_message(<<0x4600::16>>, 2)
    assert message == <<70, 0, 0, 2, 227>>
    message = SCD30.build_message(<<0x4600::16>>, 5)
    assert message == <<70, 0, 0, 5, 116>>
    message = SCD30.build_message(<<0x0010::16>>, 1000)
    assert message == <<0, 16, 3, 232, 212>>
  end

  test "convert_single_measurement_bytes_to_float/1" do
    bytes = <<0x43::8, 0xDB::8, 0xCB::8, 0x8C::8, 0x2E::8, 0x8F::8>>
    result = SCD30.convert_single_measurement_bytes_to_float(bytes)
    assert_in_delta(result, 439.09, 0.01)

    bytes = <<0x41::8, 0xD9::8, 0x70::8, 0xE7::8, 0xFF::8, 0xF5::8>>
    result = SCD30.convert_single_measurement_bytes_to_float(bytes)
    assert_in_delta(result, 27.2, 0.1)

    bytes = <<0x42::8, 0x43::8, 0xBF::8, 0x3A::8, 0x1B::8, 0x74::8>>
    result = SCD30.convert_single_measurement_bytes_to_float(bytes)
    assert_in_delta(result, 48.8, 0.1)
  end

  test "parse_read_measurement/1, valid" do
    bytes = <<0x43::8, 0xDB::8, 0xCB::8, 0x8C::8, 0x2E::8, 0x8F::8>> <>
            <<0x41::8, 0xD9::8, 0x70::8, 0xE7::8, 0xFF::8, 0xF5::8>> <>
            <<0x42::8, 0x43::8, 0xBF::8, 0x3A::8, 0x1B::8, 0x74::8>>

    %{} = measurement = SCD30.parse_read_measurement(bytes)

    assert_in_delta(measurement.co2_ppm,             439.09, 0.01)
    assert_in_delta(measurement.temperature_celsius, 27.2,   0.1)
    assert_in_delta(measurement.humidity_percent,    48.8,   0.1)
  end

  test "parse_read_measurement/1, invalid parts" do
    bytes = <<0x43::8, 0xDB::8, 0xCB::8, 0x8C::8, 0x2E::8, 0x8F::8>> <>
            <<0x41::8, 0xD9::8, 0x71::8, 0xE7::8, 0xFF::8, 0xF5::8>> <>
            <<0x43::8, 0x43::8, 0xBF::8, 0x3A::8, 0x1B::8, 0x74::8>>

    %{} = measurement = SCD30.parse_read_measurement(bytes)

    assert_in_delta(measurement.co2_ppm, 439.09, 0.01)
    assert measurement.temperature_celsius == nil
    assert measurement.humidity_percent    == nil
  end

end
