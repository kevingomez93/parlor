defmodule Parlor.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ParlorWeb.Telemetry,
      Parlor.Repo,
      {DNSCluster, query: Application.get_env(:parlor, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Parlor.PubSub},
      {Horde.Registry, name: Parlor.RoomRegistry, keys: :unique, members: :auto},
      {Horde.DynamicSupervisor,
       name: Parlor.RoomSupervisor,
       strategy: :one_for_one,
       distribution_strategy: Horde.UniformDistribution,
       members: :auto},
      {Horde.Registry, name: Parlor.YDocRegistry, keys: :unique, members: :auto},
      {Horde.DynamicSupervisor,
       name: Parlor.YDocSupervisor,
       strategy: :one_for_one,
       distribution_strategy: Horde.UniformDistribution,
       members: :auto},
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
