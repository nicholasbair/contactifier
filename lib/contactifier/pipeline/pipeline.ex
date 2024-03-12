defmodule Contactifier.Pipeline do
  @moduledoc """
  Pipeline for processing data from message webhooks, historic and incremental sync.
  """

  use Broadway
  require Logger

  alias Broadway.Message
  alias Contactifier.{
    Contacts,
    Messages.Worker,
    Pipeline.Transaction,
  }

  @processor_concurrency 5
  @max_demand 2
  @queue "messages"

  def insert({integration, page}) when is_list(page) do
    page
    |> Enum.each(fn message ->
      message = Miss.Map.from_nested_struct(message)
      integration = Miss.Map.from_nested_struct(integration, [{NaiveDateTime, :skip}])

      %Transaction{raw: message, integration: integration}
      |> Jason.encode!()
      |> publish_to_messages_queue()
    end)
  end

  def insert(message) do
    %Transaction{raw: message}
    |> Jason.encode!()
    |> publish_to_messages_queue()
  end

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {BroadwayRabbitMQ.Producer,
          queue: @queue,
          declare: [
            durable: true,
          ],
          qos: [
            prefetch_count: @processor_concurrency * @max_demand,
          ],
          on_failure: :reject_and_requeue_once,
        },
        concurrency: 1,
        transformer: {__MODULE__, :transform, []}
      ],
      processors: [
        default: [
          concurrency: @processor_concurrency,
          max_demand: @max_demand
        ]
      ],
      batchers: [
        default: [
          batch_size: @processor_concurrency * @max_demand,
          batch_timeout: 1500,
          concurrency: 1
        ]
      ]
    )
  end

  # Message created and truncated webhooks
  def handle_message(_, %{data: %{raw: raw, integration: nil}} = message, _) do
    raw
    |> Worker.message_created_workflow()
    |> apply_output(message)
  end

  # Historic / Incremental sync
  def handle_message(_, %{data: %{raw: raw, integration: integration}} = message, _) do
    %{integration: integration, message: raw}
    |> Worker.process_message_workflow()
    |> apply_output(message)
  end

  def handle_batch(_batch_name, messages, _batch_info, _context) do
    {count, _} =
      messages
      |> Enum.map(&(&1.data.output))
      |> List.flatten()
      |> Enum.uniq()
      |> Contacts.bulk_insert_contacts()

    Logger.info("Pipeline: batcher inserted #{count} contacts")

    messages
  end

  def handle_failed(messages, _context) do
    Logger.error("Pipeline: failed to process messages: #{inspect(messages)}")
    messages
  end

  def transform(message, _opts) do
    %{"raw" => raw, "integration" => integration} = Jason.decode!(message.data)
    Message.put_data(message, %Transaction{raw: raw, integration: integration})
  end

  # -- Private --

  defp apply_output(output, message) do
    %Message{ message | data: Map.put(message.data, :output, output) }
  end

  defp publish_to_messages_queue(message) do
    {:ok, chan} = AMQP.Application.get_channel(:messages)
    :ok = AMQP.Basic.publish(chan, "", @queue, message, persistent: false)
  end
end
