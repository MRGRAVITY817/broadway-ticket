defmodule BroadwayTickets.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BookingsPipeline,
      NotificationsPipeline
    ]

    opts = [strategy: :one_for_one, name: BroadwayTickets.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
