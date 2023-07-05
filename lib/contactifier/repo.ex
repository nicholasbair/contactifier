defmodule Contactifier.Repo do
  use Ecto.Repo,
    otp_app: :contactifier,
    adapter: Ecto.Adapters.Postgres
end
