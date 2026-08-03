defmodule Parlor.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ParlorWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:parlor, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Parlor.PubSub},
      {Registry, keys: :unique, name: Parlor.RoomRegistry},
      {DynamicSupervisor, name: Parlor.RoomSupervisor, strategy: :one_for_one},
      ParlorWeb.Presence,
      ParlorWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Parlor.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ParlorWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
