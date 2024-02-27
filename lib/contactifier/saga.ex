defmodule Contactifier.Saga do
  @moduledoc """
  Wrapper for composing a workflow with some branching and fallback logic.

  Heavily inspired by the Sage library - https://github.com/Nebo15/sage, the aim being to make a super lightweight version for my specific use case.

  Each transaction must accept the effects map and the attrs and return one of the following:
    - :ok -> continue to the next transaction without storing any new values in the effects
    - {:ok, val} -> continue to the next transaction and store `val` in the effects
    - {:error, error} -> run the compensation for the current transaction and do not run any further transactions

  Each compensation must accept the error, effects and the attrs and return one of the following:
    - :ok, :cancel, :abort_with_error, {:ok, val}, {:cancel, message}, {:abort_with_error, message}
    - The behaviour of each of these is described below

  - :ok -> continue to the next transaction without storing any new values in the effects

  Use the error message from the transaction
    - :cancel -> stop the saga and do not run any further transactions, `{:cancel, error_from_transaction}` will be returned in the final result of the saga
    - :abort_with_error -> stop the saga and do not run any further transactions, `{:abort_with_error, error_from_transaction}` will be returned in the final result of the saga

  Use a custom value or error message
    - {:ok, val} -> continue to the next transaction and store `val` in the effects
    - {:cancel, `message`} -> stop the saga and do not run any further transactions, `{:cancel, message}` will be returned in the final result of the saga
    - {:abort_with_error, `message`} -> stop the saga and do not run any further transactions, `{:abort_with_error, message}` will be returned in the final result of the saga
  """

  defstruct [
    :effects,
    :attrs,
    :exit,
    :final
  ]

  def new(attrs \\ %{}) do
    %__MODULE__{
      effects: %{},
      attrs: attrs,
      exit: false,
    }
  end

  def run(saga, name, transaction, compensation \\ nil)
  def run(%{exit: true} = saga, _name, _transaction, _compensation), do: saga

  def run(saga, name, transaction, compensation) when is_nil(compensation) do
    val =
      transaction.(saga.effects, saga.attrs)
      |> unwrap()

    %{saga | effects: Map.put(saga.effects, name, val)}
  end

  def run(saga, name, transaction, compensation) do
    case transaction.(saga.effects, saga.attrs) do
      :ok ->
        saga

      {:ok, val} ->
        %{saga | effects: Map.put(saga.effects, name, val)}

      {:error, error} ->
        case compensation.(error, saga.effects, saga.attrs) do
          :ok ->
            saga

          :cancel ->
            %{saga | exit: true, final: {:cancel, error}}

          :abort_with_error ->
            %{saga | exit: true, final: {:abort_with_error, error}}

          {:ok, val} ->
            %{saga | effects: Map.put(saga.effects, name, val)}

          {:cancel, message} ->
            %{saga | exit: true, final: {:cancel, message}}

          {:abort_with_error, message} ->
            %{saga | exit: true, final: {:abort_with_error, message}}
        end
    end
  end


  def finally(%{exit: true, final: final}), do: final
  def finally(_saga), do: :ok

  defp unwrap({_, val}), do: val
  defp unwrap(val), do: val
end
