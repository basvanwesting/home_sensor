# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
import Config

config :home_sensor, target: Mix.target()

# Customize non-Elixir parts of the firmware. See
# https://hexdocs.pm/nerves/advanced-configuration.html for details.

config :nerves, :firmware,
  rootfs_overlay: "rootfs_overlay",
  provisioning: :nerves_hub_link

config :nerves_hub_link,
  configurator: HomeSensor.Configurator,
  socket: [
    json_library: Jason,
    heartbeat_interval: 45_000
  ],
  remote_iex: true,
  fwup_public_keys: [:devkey]

# Set the SOURCE_DATE_EPOCH date for reproducible builds.
# See https://reproducible-builds.org/docs/source-date-epoch/ for more information

config :nerves, source_date_epoch: "1602672084"

# Use Ringlogger as the logger backend and remove :console.
# See https://hexdocs.pm/ring_logger/readme.html for more information on
# configuring ring_logger.

config :logger, backends: [RingLogger]

#config :amqp, :sensor_measurements_queue, nil
#config :amqp, :connection_options,
  #host:     nil,
  #username: nil,
  #password: nil

if Mix.target() != :host do
  import_config "target.exs"
end
