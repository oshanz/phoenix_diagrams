import Config

config :ex_diag, ExDiag.TestEndpoint,
  url: [host: "localhost"],
  secret_key_base: String.duplicate("a", 64),
  live_view: [signing_salt: String.duplicate("b", 8)],
  server: false
