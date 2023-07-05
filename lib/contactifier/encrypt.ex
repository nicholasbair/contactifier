defmodule Contactifier.Vault do
  use Cloak.Vault, otp_app: :contactifier
end

defmodule Contactifier.Encrypted.Binary do
  use Cloak.Ecto.Binary, vault: Contactifier.Vault
end
