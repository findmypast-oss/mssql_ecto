defmodule Ecto.Integration.TypeParserTest do
  use Ecto.Integration.Case, async: Application.get_env(:ecto, :async_integration_tests, true)

  alias Ecto.Integration.TestRepo
  import Ecto.Query

  alias Ecto.Integration.Post
  alias Ecto.Integration.Comment
  alias Ecto.Integration.Permalink
  alias Ecto.Integration.User
  alias Ecto.Integration.PostUserCompositePk

  test "joins with column alias" do
    _p = TestRepo.insert!(%Post{title: "1"})
    p2 = TestRepo.insert!(%Post{title: "2"})
    c1 = TestRepo.insert!(%Permalink{url: "1", post_id: p2.id})

    query =
      from(p in Post,
        join: c in assoc(p, :permalink),
        on: c.id == ^c1.id,
        select: %{post_id: p.id, link_id: c.id}
      )

    expected = %{link_id: c1.id, post_id: p2.id}
    assert [expected] = TestRepo.all(query)
  end
end
