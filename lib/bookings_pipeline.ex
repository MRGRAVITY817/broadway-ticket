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
      ],
      batchers: [
        cinema: [],
        musical: [],
        default: []
      ]
    ]

    Broadway.start_link(__MODULE__, options)
  end

  def handle_batch(_batcher, messages, batch_info, _context) do
    IO.inspect(batch_info,
      label: "#{inspect(self())} Batch #{batch_info.batcher} #{batch_info.batch_key}"
    )

    messages
    |> BroadwayTickets.insert_all_tickets()
    |> Enum.each(fn %{data: %{user: user}} ->
      BroadwayTickets.send_email(user)
    end)

    messages
  end

  # This is handled on new process, created by Broadway.
  def handle_message(_processor, message, _context) do
    if BroadwayTickets.tickets_available?(message.data.event) do
      case message do
        %{data: %{event: "cinema"}} = message ->
          Broadway.Message.put_batcher(message, :cinema)

        %{data: %{event: "musical"}} = message ->
          Broadway.Message.put_batcher(message, :musical)

        message ->
          message
      end
    else
      Broadway.Message.failed(message, "bookings-closed")
    end
  end

  # Handle when `Broadway.Message.failed()` is called
  def handle_failed(messages, _context) do
    IO.inspect(messages, label: "Failed messages")

    Enum.map(messages, fn
      %{status: {:failed, "bookings-closed"}} = message ->
        Broadway.Message.configure_ack(message, on_failure: :reject)

      message ->
        message
    end)
  end

  # Does preparation before handle_message() is being called
  def prepare_messages(messages, _context) do
    # Parse data and convert to a map.
    messages =
      Enum.map(messages, fn message ->
        Broadway.Message.update_data(message, fn data ->
          [event, user_id] = String.split(data, ",")
          %{event: event, user_id: user_id}
        end)
      end)

    users = BroadwayTickets.users_by_ids(Enum.map(messages, & &1.data.user_id))

    # Put users in messages
    Enum.map(messages, fn message ->
      Broadway.Message.update_data(message, fn data ->
        user = Enum.find(users, &(&1.id == data.user_id))
        Map.put(data, :user, user)
      end)
    end)
  end
end
