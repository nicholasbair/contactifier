defmodule ContactifierWeb.WebhookController do
  use ContactifierWeb, :controller

  alias Contactifier.{
    Integrations,
    Pipeline
  }

  def challenge(conn, params) do
    text(conn, params["challenge"])
  end

  # Note - webhooks are verified upstream in the pipeline, see webhook_util.ex
  def receive_webhook(conn, %{"type" => type} = params) when type in ["message.created", "message.created.truncated"] do
    Pipeline.insert(params)
    send_resp(conn, 200, "")
  end

  def receive_webhook(conn, %{"type" => "grant.expired", "object" => %{"grant_id" => id}} = _params) do
    # This is a fairly simple operation, so not using an async job
    with {:ok, integration} <- Integrations.get_integration_by_vendor_id(id) do
      Integrations.update_integration(integration, %{integration | valid?: false, invalid_since: DateTime.utc_now()})
    end

    send_resp(conn, 200, "")
  end
end
