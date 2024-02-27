defmodule Contactifier.Integrations.Proposals do
  @moduledoc """

  """

  import Ecto.Query, warn: false
  alias Contactifier.Repo

  alias Contactifier.Integrations.Proposal

  # 10 minutes
  @max_age 600_000

  @doc """
  Creates a proposal.

  ## Examples

      iex> create_proposal(%{field: value})
      {:ok, %Proposal{}}

      iex> create_proposal(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_proposal(attrs \\ %{}) do
    %Proposal{}
    |> Proposal.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a single proposal.

  ## Examples

      iex> get_proposal(123)
      {:ok, %Proposal{}}

      iex> get_proposal(456)
      {:error, :not_found}

  """
  def get_proposal(id) do
    Proposal
    |> Repo.get(id)
    |> Repo.normalize_one()
  end

  @doc """
  Check if a proposal is expired.

  ## Examples

      iex> expired?(%Proposal{inserted_at: 1234})
      true

      iex> expired?(%Proposal{inserted_at: 5678})
      false
  """
  def expired?(%Proposal{inserted_at: inserted_at}) do
    naive_inserted_at = DateTime.from_naive!(inserted_at, "Etc/UTC")

    DateTime.utc_now()
    |> DateTime.diff(naive_inserted_at) > @max_age
  end

  @doc """
  Deletes a proposal.

  ## Examples

      iex> delete_proposal(proposal)
      {:ok, %Proposal{}}

      iex> delete_proposal(proposal)
      {:error, %Ecto.Changeset{}}

  """
  def delete_proposal(%Proposal{} = proposal) do
    Repo.delete(proposal)
  end

  @doc """
  Returns the list of expired proposals.

  ## Examples

      iex> list_expired_proposals()
      [%Proposal{}, ...]

  """
  def list_expired_proposals() do
    t =
      DateTime.utc_now()
      |> DateTime.add(-@max_age)

    Repo.all(from p in Proposal, where: p.inserted_at <= ^t)
  end
end
