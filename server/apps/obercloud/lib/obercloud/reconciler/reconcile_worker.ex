defmodule OberCloud.Reconciler.ReconcileWorker do
  use Oban.Worker, queue: :reconcile, max_attempts: 5

  alias OberCloud.Reconciler.{DesiredState, HclRenderer, TofuRunner}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"desired_state_id" => id}}) do
    ds = Ash.get!(DesiredState, id, authorize?: false)

    {:ok, _} =
      ds
      |> Ash.Changeset.for_update(:mark_reconciling)
      |> Ash.update(authorize?: false)

    case do_reconcile(ds) do
      :ok ->
        {:ok, ready} =
          ds
          |> Ash.Changeset.for_update(:mark_ready)
          |> Ash.update(authorize?: false)

        broadcast(ready)
        :ok

      {:error, reason} ->
        {:ok, failed} =
          ds
          |> Ash.Changeset.for_update(:mark_failed, %{error: inspect(reason)})
          |> Ash.update(authorize?: false)

        broadcast(failed)
        {:error, reason}
    end
  end

  defp do_reconcile(ds) do
    hcl = HclRenderer.render(ds.spec, "test-stub-token", "ds-#{ds.id}")

    with {:ok, %{exit_code: 0}} <- TofuRunner.run(hcl, ["init", "-no-color"]),
         {:ok, %{exit_code: 0}} <- TofuRunner.run(hcl, ["apply", "-auto-approve", "-no-color"]) do
      :ok
    else
      {:ok, %{exit_code: code, stdout: out}} -> {:error, "tofu exit #{code}: #{out}"}
      err -> err
    end
  end

  defp broadcast(ds) do
    Phoenix.PubSub.broadcast(
      OberCloud.PubSub,
      "desired_state:#{ds.org_id}",
      {:reconcile_update, ds}
    )
  end
end
