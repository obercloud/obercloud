defmodule OberCloud.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      OberCloud.Repo,
      {DNSCluster, query: Application.get_env(:obercloud, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: OberCloud.PubSub},
      {Oban, Application.fetch_env!(:obercloud, Oban)}
      # Start a worker by calling: OberCloud.Worker.start_link(arg)
      # {OberCloud.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: OberCloud.Supervisor)
  end
end
