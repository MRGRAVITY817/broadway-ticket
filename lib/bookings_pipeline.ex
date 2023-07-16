defmodule BookingsPipeline do
  use Broadway

  @producer BroadwayRabbitMQ.Producer

  @producer_config [
    queue: "bookings_queue",
    declare: [durable: true],
    on_failure: :reject_and_requeue
  ]

  def start_link(_args) do
    options = [
      name: BookingsPipeline,
      producer: [
        module: {@producer, @producer_config}
        # You can set concurrency options
        # concurrency: 1
      ],
      processors: [
        default: [
          # You can set concurrency options
          # concurrency: System.schedulers_online() * 2
        ]
      ]
    ]

    Broadway.start_link(__MODULE__, options)
  end

  # This is handled on new process, created by Broadway.
  def handle_message(_processor, message, _context) do
    IO.inspect(message, label: "Message")
  end
end
