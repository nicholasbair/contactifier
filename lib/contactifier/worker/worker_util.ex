defmodule Contactifier.Worker.Util do

  @doc """
  Map the output of a Saga to the values expected by Oban
  """
  def maybe_cancel_job(%{final: {:cancel, reason}}), do: {:cancel, reason}
  def maybe_cancel_job(%{final: {:abort_with_error, reason}}), do: {:error, reason}
  def maybe_cancel_job(_), do: :ok

end
