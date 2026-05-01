defmodule OberCloud.Crypto do
  @moduledoc "AES-256-GCM encryption for storing provider credentials at rest."

  @aad "obercloud:provider_credential:v1"

  def encrypt(plaintext) when is_binary(plaintext) do
    key = key()
    iv = :crypto.strong_rand_bytes(12)
    {ct, tag} =
      :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, @aad, true)
    iv <> tag <> ct
  end

  def decrypt(<<iv::binary-size(12), tag::binary-size(16), ct::binary>>) do
    key = key()

    case :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ct, @aad, tag, false) do
      :error -> {:error, :decryption_failed}
      pt -> {:ok, pt}
    end
  end

  defp key, do: Application.fetch_env!(:obercloud, :credential_encryption_key)
end
