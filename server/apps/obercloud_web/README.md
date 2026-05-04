# obercloud_web

The HTTP-facing umbrella app: Phoenix endpoint, LiveView pages, and the
AshJsonApi REST router. Pairs with the `obercloud` core app.

For end-user installation and usage, see the **[top-level INSTALL.md](../../../docs/INSTALL.md)**.

To run from this directory during development:

```bash
mix setup
mix phx.server
```

Then visit <http://localhost:4000>.

## Tech

- [Phoenix](https://hexdocs.pm/phoenix/)
- [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/)
- [AshJsonApi](https://hexdocs.pm/ash_json_api/) for the REST API
- [AshAuthentication.Phoenix](https://hexdocs.pm/ash_authentication_phoenix/) for sign-in/sign-out
