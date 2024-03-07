defmodule Contactifier.Pipeline do
  @moduledoc """
  Pipeline for processing data from message webhooks, historic and incremental sync.
  """

  alias Contactifier.Pipeline.Consumer

  def insert({metadata, page}) when is_list(page) do
    page
    |> Enum.each(&call({metadata, &1}))
  end

  def insert(event), do: call(event)

  defp call(event) do
    Consumer
    |> Broadway.producer_names()
    |> List.first() # Broadway only allows one producer
    |> GenServer.call(event)
  end

  defmodule Transaction do
    @moduledoc """
    A struct to represent a transaction in the pipeline.
    """

    defstruct [
      :raw, # Raw input value from the producer, either a map, list, or tuple
      output: [] # Output value to be sent to the next stage
    ]
  end
end
