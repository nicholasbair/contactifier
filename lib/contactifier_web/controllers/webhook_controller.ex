defmodule ContactifierWeb.WebhookController do
  use ContactifierWeb, :controller

  def challenge(conn, params) do
    text(conn, params["challenge"])
  end

  def receive_webhook(conn, %{"deltas" => [%{"type" => "contact.created", "object_data" => %{"id" => id}} | _tail]} = _params) do
    # Not verifying webhook signature, Phoenix doesn't expose the raw payload in the controller,
    # there is a hack to get this value but avoiding for simplicity
    # ref: https://github.com/phoenixframework/phoenix/issues/459#issuecomment-889050289

    # TODO: check if account ID matches a Nylas account in intergations table

    # TODO: implement insert => should create Oban job
    # Contactifier.WebhookHandler.insert(id)
    send_resp(conn, 200, "")
  end

end
