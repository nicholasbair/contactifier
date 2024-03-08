defmodule Contactifier.Pipeline.Producer do
  @moduledoc """
  Webhook producer for the Contactifier data pipeline.
  """

  use GenStage

  @impl true
  def init(_) do
    {:producer, []}
  end

  @impl true
  def handle_demand(_demand, state) do
    {:noreply, [], state}
  end

  @impl true
  def handle_call(event, _from, state) do
    {:reply, :ok, [event], [event | state]}
  end
end
