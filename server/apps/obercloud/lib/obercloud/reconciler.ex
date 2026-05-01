defmodule OberCloud.Reconciler do
  use Ash.Domain, otp_app: :obercloud

  resources do
    resource OberCloud.Reconciler.DesiredState
  end
end
