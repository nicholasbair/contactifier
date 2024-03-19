defmodule Contactifier.Pipeline.Transaction do
  @moduledoc """
  A struct to represent a transaction in the pipeline.
  """

  @derive {Jason.Encoder, only: [:raw, :integration, :output]}

  defstruct [
    :raw, # Raw input value from the producer, either a map, list, or tuple
    :integration, # Integration to use in the transaction, present on data from historic and incremental sync to avoid fetching the integration for each object
    output: [] # Output value to be sent to the next stage
  ]
end
