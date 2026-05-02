defmodule OberCloud.Reconciler.DriftDetector do
  use Oban.Worker, queue: :drift

  require Ash.Query

  alias OberCloud.Reconciler.{DesiredState, ReconcileWorker}

  @impl Oban.Worker
  def perform(_job) do
    drifted =
      DesiredState
      |> Ash.Query.filter(reconcile_status == "drifted")
      |> Ash.read!(authorize?: false)

    Enum.each(drifted, fn ds ->
      %{desired_state_id: ds.id} |> ReconcileWorker.new() |> Oban.insert!()
    end)

    :ok
  end
end
