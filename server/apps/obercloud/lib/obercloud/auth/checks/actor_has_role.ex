defmodule OberCloud.Auth.Checks.ActorHasRole do
  use Ash.Policy.SimpleCheck

  require Ash.Query

  @hierarchy %{
    "system:owner" => 100,
    "org:owner" => 50,
    "org:admin" => 40,
    "org:member" => 30,
    "org:viewer" => 20
  }

  @impl true
  def describe(opts), do: "actor has role >= #{inspect(opts[:role])}"

  @impl true
  def match?(nil, _, _), do: false

  def match?(%{type: :api_key, role: role}, _, opts) do
    role_satisfies?(role, Keyword.fetch!(opts, :role))
  end

  def match?(%{type: :user, id: uid}, %{changeset: cs}, opts) do
    oid = extract_org_id(cs)
    user_role_satisfies?(uid, oid, Keyword.fetch!(opts, :role))
  end

  def match?(_, _, _), do: false

  defp user_role_satisfies?(_uid, nil, _), do: false

  defp user_role_satisfies?(uid, oid, required) do
    case OberCloud.Accounts.Membership
         |> Ash.Query.filter(user_id == ^uid and org_id == ^oid)
         |> Ash.read_one() do
      {:ok, %{role: role}} -> role_satisfies?(role, required)
      _ -> false
    end
  end

  defp role_satisfies?(actor_role, required_role) do
    Map.get(@hierarchy, actor_role, 0) >= Map.get(@hierarchy, required_role, 999)
  end

  defp extract_org_id(%Ash.Changeset{attributes: %{org_id: id}}), do: id
  defp extract_org_id(%Ash.Changeset{data: %{org_id: id}}), do: id
  defp extract_org_id(_), do: nil
end
