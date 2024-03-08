defmodule Contactifier.Pipeline.Consumer do
  @moduledoc """
  Consumer for the Contactifier data pipeline.

  Known issues:
  - No backpressure
  - All messaged are acked (even if they fail)
  - No retries
  """

  use Broadway
  require Logger

  alias Broadway.Message
  alias Contactifier.{
    Contacts,
    Messages.Worker,
    Pipeline.Producer,
    Pipeline.Transaction,
  }

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {Producer, []},
        transformer: {__MODULE__, :transform, []}
      ],
      processors: [
        default: [concurrency: 2]
      ],
      batchers: [
        default: [
          batch_size: 20,
          batch_timeout: 5000,
          concurrency: 1
        ]
      ]
    )
  end

  # Message created and truncated webhooks
  def handle_message(_, %{data: %{raw: raw}} = message, _) when is_map(raw) do
    raw
    |> Worker.message_created_workflow()
    |> apply_output(message)
  end

  # Historic / Incremental sync
  def handle_message(_, %{data: %{raw: {integration, raw}}} = message, _) do
    %{integration: integration, message: raw}
    |> Worker.parse_emails_from_message(nil)
    |> apply_output(message)
  end

  def handle_batch(_batch_name, messages, _batch_info, _context) do
    {count, _} =
      messages
      |> Enum.map(&(&1.data.output))
      |> List.flatten()
      |> Enum.uniq()
      |> Contacts.bulk_insert_contacts()

    Logger.info("Batcher inserted #{count} contacts")

    messages
  end

  def transform(event, _opts) do
    %Message{
      data: %Transaction{raw: event},
      acknowledger: {__MODULE__, :ack_id, :ack_data}
    }
  end

  def ack(:ack_id, _successful, _failed) do
    :ok
  end

  def apply_output(output, message) do
    %Message{ message | data: Map.put(message.data, :output, output) }
  end
end
