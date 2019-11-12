ExUnit.start()
Application.ensure_all_started(:bypass)

Mox.defmock(MockClient, for: Twirp.TestService.Client)
