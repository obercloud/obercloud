{:ok, user} =
  OberCloud.Accounts.User
  |> Ash.Changeset.for_create(:register_with_password, %{
    email: "admin@local",
    name: "Admin",
    password: "changeme1234",
    password_confirmation: "changeme1234"
  })
  |> Ash.create(authorize?: false)

{:ok, org} =
  Ash.create(
    OberCloud.Accounts.Org,
    %{name: "My Org", slug: "my-org"},
    authorize?: false
  )

{:ok, _membership} =
  Ash.create(
    OberCloud.Accounts.Membership,
    %{user_id: user.id, org_id: org.id, role: "org:owner"},
    authorize?: false
  )

{:ok, %{plaintext: pt}} =
  OberCloud.Auth.ApiKey.create_with_plaintext(%{
    name: "local-dev",
    org_id: org.id,
    role: "org:admin"
  })

IO.puts("""

============================================
  User:    admin@local / changeme1234
  Org id:  #{org.id}
  API key: #{pt}
============================================
You will not see the API key again — copy it now.
""")
