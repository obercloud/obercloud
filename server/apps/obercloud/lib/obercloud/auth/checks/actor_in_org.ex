defmodule OberCloud.Auth.Checks.ActorInOrg do
  use Ash.Policy.SimpleCheck

  require Ash.Query

  @impl true
  def describe(_), do: "actor is a member of the resource's org"

  @impl true
  def match?(nil, _, _), do: false
  def match?(actor, %{changeset: cs}, _), do: org_id_match?(actor, extract_cs(cs))
  def match?(actor, %{query: q}, _), do: org_id_match?(actor, extract_q(q))
  def match?(_, _, _), do: false

  defp org_id_match?(%{type: :api_key, org_id: aid}, oid),
    do: not is_nil(oid) and aid == oid

  defp org_id_match?(%{type: :user, id: uid}, oid)
       when not is_nil(uid) and not is_nil(oid) do
    case OberCloud.Accounts.Membership
         |> Ash.Query.filter(user_id == ^uid and org_id == ^oid)
         |> Ash.read_one() do
      {:ok, nil} -> false
      {:ok, _} -> true
      _ -> false
    end
  end

  defp org_id_match?(_, _), do: false

  defp extract_cs(%Ash.Changeset{attributes: %{org_id: id}}), do: id
  defp extract_cs(%Ash.Changeset{data: %{org_id: id}}), do: id
  defp extract_cs(_), do: nil

  defp extract_q(_), do: nil
end
