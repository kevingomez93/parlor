defmodule ParlorWeb.Layouts do
  @moduledoc false

  use ParlorWeb, :html

  import Phoenix.LiveView.JS

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="admin-header">
      <div>
        <a href={~p"/admin"} class="brand">Parlor Admin</a>
      </div>
      <.flash_group flash={@flash} />
    </header>
    <main class="admin-main">
      {render_slot(@inner_block)}
    </main>
    """
  end

  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"
  attr :kind, :atom, values: [:info, :error], doc: "used internally by flash_group"
  attr :title, :string, default: nil
  attr :close, :boolean, default: true

  slot :inner_block, doc: "the inner block that renders the flash message"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} class="flash-group">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
    </div>
    """
  end

  attr :kind, :atom, values: [:info, :error], required: true
  attr :flash, :map, required: true
  attr :title, :string, default: nil
  attr :close, :boolean, default: true

  slot :inner_block

  def flash(assigns) do
    ~H"""
    <div
      :if={msg = Phoenix.Flash.get(@flash, @kind)}
      class={"flash flash-#{@kind}"}
      role="alert"
      phx-click={push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@kind}")}
      id={@kind}
    >
      <p :if={@title}>{@title}</p>
      {msg}
      {render_slot(@inner_block)}
    </div>
    """
  end
end
