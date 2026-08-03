defmodule ParlorWeb.ErrorJSONTest do
  use ParlorWeb.ConnCase, async: true

  test "renders 404" do
    assert ParlorWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert ParlorWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
