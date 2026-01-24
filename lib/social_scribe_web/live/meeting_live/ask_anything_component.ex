defmodule SocialScribeWeb.MeetingLive.AskAnythingComponent do
  @moduledoc """
  Ask Anything chat interface for asking questions about CRM contacts and meetings.
  Supports both HubSpot and Salesforce contacts with @ mention tagging.
  """
  use SocialScribeWeb, :live_component

  import SocialScribeWeb.ModalComponents, only: [avatar: 1]

  @impl true
  def render(assigns) do
    ~H"""
    <div class={["flex flex-col bg-white rounded-2xl shadow-lg overflow-hidden", @collapsed && "h-auto"]}>
      <!-- Header -->
      <div class="px-6 py-4">
        <div class="flex justify-between items-center">
          <h2 class="text-2xl font-bold text-slate-900">Ask Anything</h2>
          <button
            type="button"
            phx-click="toggle_collapse"
            phx-target={@myself}
            class="text-slate-400 hover:text-slate-600 text-xl font-semibold"
          >
            &raquo;
          </button>
        </div>

        <!-- Tabs -->
        <div :if={!@collapsed} class="flex items-center gap-4 mt-3">
          <button
            type="button"
            phx-click="switch_tab"
            phx-value-tab="chat"
            phx-target={@myself}
            class={[
              "px-4 py-1.5 text-sm font-medium rounded-full transition-colors",
              @active_tab == :chat && "bg-slate-100 text-slate-900",
              @active_tab != :chat && "text-slate-500 hover:text-slate-700"
            ]}
          >
            Chat
          </button>
          <button
            type="button"
            phx-click="switch_tab"
            phx-value-tab="history"
            phx-target={@myself}
            class={[
              "text-sm font-medium transition-colors",
              @active_tab == :history && "text-slate-900",
              @active_tab != :history && "text-slate-500 hover:text-slate-700"
            ]}
          >
            History
          </button>
          <button
            type="button"
            phx-click="new_chat"
            phx-target={@myself}
            class="ml-auto text-slate-400 hover:text-slate-600 text-xl font-medium"
          >
            +
          </button>
        </div>
      </div>

      <%= if !@collapsed do %>
        <!-- Date Separator -->
        <div class="flex items-center px-6 py-2">
          <div class="flex-1 h-px bg-slate-200"></div>
          <span class="px-4 text-xs text-slate-400">{format_session_date(@session_started_at)}</span>
          <div class="flex-1 h-px bg-slate-200"></div>
        </div>

        <!-- Chat Tab Content -->
        <%= if @active_tab == :chat do %>
          <!-- Messages Area -->
          <div
            class="flex-1 overflow-y-auto px-6 py-4 space-y-4 min-h-[300px] max-h-[400px]"
            id={"#{@id}-messages"}
            phx-hook="ScrollToBottom"
          >
            <!-- Welcome message -->
            <%= if Enum.empty?(@messages) do %>
              <p class="text-slate-700">I can answer questions about Jump meetings and data – just ask!</p>
            <% end %>

            <!-- Messages -->
            <div :for={message <- @messages} class="space-y-1">
              <%= if message.role == "user" do %>
                <!-- User message (gray bubble) -->
                <div class="bg-slate-100 rounded-2xl px-4 py-3 max-w-[85%] inline-block">
                  <span>{message.content}</span>
                </div>
              <% else %>
                <!-- AI/System response (no bubble) -->
                <div class="text-slate-700">
                  {render_ai_response(message)}
                </div>
                <%= if message.sources && Enum.any?(message.sources) do %>
                  <div class="text-sm flex items-center gap-2 mt-1">
                    <span class="text-slate-400">Sources</span>
                    <span :for={source <- message.sources}>
                      <%= if source.type == :meeting do %>
                        <span class="text-lg" title={source.title}>&#x1F399;&#xFE0F;</span>
                      <% end %>
                    </span>
                  </div>
                <% end %>
              <% end %>
            </div>

            <!-- Loading indicator -->
            <%= if @loading do %>
              <div class="text-slate-500 flex items-center gap-2">
                <div class="flex gap-1">
                  <div class="w-2 h-2 bg-slate-400 rounded-full animate-bounce" style="animation-delay: 0ms"></div>
                  <div class="w-2 h-2 bg-slate-400 rounded-full animate-bounce" style="animation-delay: 150ms"></div>
                  <div class="w-2 h-2 bg-slate-400 rounded-full animate-bounce" style="animation-delay: 300ms"></div>
                </div>
                <span class="text-sm">Thinking...</span>
              </div>
            <% end %>
          </div>

          <!-- Contact Search Picker -->
          <div :if={@show_contact_picker} class="mx-4 mb-2 border border-slate-200 rounded-xl p-3 bg-slate-50">
            <div class="flex items-center justify-between mb-2">
              <span class="text-sm font-medium text-slate-700">Search for a contact</span>
              <button
                type="button"
                phx-click="close_contact_picker"
                phx-target={@myself}
                class="text-slate-400 hover:text-slate-600"
              >
                <.icon name="hero-x-mark" class="w-4 h-4" />
              </button>
            </div>
            <input
              type="text"
              name="contact_search"
              value={@contact_search_query}
              placeholder="Type a name to search..."
              phx-keyup="search_contacts"
              phx-target={@myself}
              phx-debounce="200"
              autocomplete="off"
              class="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-slate-400"
            />
            <!-- Search Results -->
            <div :if={Enum.any?(@contact_suggestions)} class="mt-2 max-h-40 overflow-y-auto">
              <button
                :for={contact <- @contact_suggestions}
                type="button"
                phx-click="select_contact"
                phx-value-id={contact.id}
                phx-value-crm={contact.crm_type}
                phx-target={@myself}
                class="w-full flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-white transition-colors"
              >
                <.avatar firstname={contact.firstname} lastname={contact.lastname} size={:sm} />
                <div class="flex-1 text-left">
                  <p class="text-sm font-medium text-slate-800">{contact.display_name}</p>
                  <p class="text-xs text-slate-500">{contact.email}</p>
                </div>
                <span class={[
                  "text-xs px-2 py-0.5 rounded-full",
                  contact.crm_type == "hubspot" && "bg-orange-100 text-orange-700",
                  contact.crm_type == "salesforce" && "bg-blue-100 text-blue-700"
                ]}>
                  {String.capitalize(contact.crm_type)}
                </span>
              </button>
            </div>
            <p :if={@contact_search_query != "" && Enum.empty?(@contact_suggestions) && !@searching_contacts} class="text-sm text-slate-500 mt-2 px-1">
              No contacts found
            </p>
            <p :if={@searching_contacts} class="text-sm text-slate-500 mt-2 px-1">
              Searching...
            </p>
          </div>

          <!-- Input Area -->
          <div class="mx-4 mb-4 border border-slate-200 rounded-xl p-3 relative">
            <!-- @ Add context button (shows when no @ in input) -->
            <button
              :if={!@show_contact_picker && !@show_inline_picker && !String.contains?(@input_value, "🗣️")}
              type="button"
              phx-click="insert_at_symbol"
              phx-target={@myself}
              class="inline-flex items-center gap-1.5 px-3 py-1.5 border border-slate-200 rounded-full text-sm mb-2 hover:bg-slate-50 transition-colors"
            >
              <span class="text-slate-400">@</span>
              <span class="text-slate-600">Add context</span>
            </button>

            <!-- Inline @ mention dropdown (appears when typing @) -->
            <div :if={@show_inline_picker && Enum.any?(@contact_suggestions)} class="absolute bottom-full left-0 right-0 mb-1 bg-white border border-slate-200 rounded-xl shadow-lg max-h-48 overflow-y-auto z-20">
              <div class="p-2">
                <p class="text-xs text-slate-500 px-2 pb-2">Select a contact</p>
                <button
                  :for={contact <- @contact_suggestions}
                  type="button"
                  phx-click="select_inline_contact"
                  phx-value-id={contact.id}
                  phx-value-crm={contact.crm_type}
                  phx-target={@myself}
                  class="w-full flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-slate-50 transition-colors"
                >
                  <.avatar firstname={contact.firstname} lastname={contact.lastname} size={:sm} />
                  <div class="flex-1 text-left">
                    <p class="text-sm font-medium text-slate-800">{contact.display_name}</p>
                    <p class="text-xs text-slate-500">{contact.email}</p>
                  </div>
                  <span class={[
                    "text-xs px-2 py-0.5 rounded-full",
                    contact.crm_type == "hubspot" && "bg-orange-100 text-orange-700",
                    contact.crm_type == "salesforce" && "bg-blue-100 text-blue-700"
                  ]}>
                    {String.capitalize(contact.crm_type)}
                  </span>
                </button>
              </div>
            </div>
            <div :if={@show_inline_picker && @searching_contacts} class="absolute bottom-full left-0 right-0 mb-1 bg-white border border-slate-200 rounded-xl shadow-lg p-3 z-20">
              <p class="text-sm text-slate-500">Searching...</p>
            </div>

            <!-- Textarea -->
            <form phx-submit="send_message" phx-change="input_change" phx-target={@myself}>
              <textarea
                name="message"
                placeholder="Ask anything about your meetings"
                phx-debounce="100"
                rows="2"
                class="w-full border-0 resize-none focus:ring-0 text-sm text-slate-700 placeholder-slate-400 p-0"
                id={"#{@id}-input"}
                phx-hook="TextareaAutoResize"
              >{@input_value}</textarea>

              <!-- Bottom bar -->
              <div class="flex justify-between items-center mt-2">
                <div class="flex items-center gap-2 text-sm text-slate-400">
                  <span>Sources</span>
                  <%= if @hubspot_credential do %>
                    <span class="w-3 h-3 rounded-full bg-orange-500" title="HubSpot"></span>
                  <% end %>
                  <%= if @salesforce_credential do %>
                    <span class="w-3 h-3 rounded-full bg-blue-500" title="Salesforce"></span>
                  <% end %>
                </div>
                <button
                  type="submit"
                  disabled={@loading || String.trim(@input_value) == ""}
                  class={[
                    "w-8 h-8 rounded-full flex items-center justify-center transition-colors",
                    (String.trim(@input_value) != "" && !@loading) && "bg-slate-800 text-white hover:bg-slate-700",
                    (String.trim(@input_value) == "" || @loading) && "bg-slate-100 text-slate-400"
                  ]}
                >
                  <.icon name="hero-arrow-up" class="w-4 h-4" />
                </button>
              </div>
            </form>
          </div>
        <% end %>

        <!-- History Tab Content -->
        <%= if @active_tab == :history do %>
          <div class="flex-1 overflow-y-auto px-6 py-4 min-h-[300px] max-h-[400px]">
            <%= if Enum.empty?(@chat_history) do %>
              <div class="flex flex-col items-center justify-center h-full text-center">
                <div class="w-12 h-12 bg-slate-100 rounded-full flex items-center justify-center mb-3">
                  <.icon name="hero-clock" class="w-6 h-6 text-slate-400" />
                </div>
                <p class="text-slate-500 text-sm">No chat history yet</p>
                <p class="text-slate-400 text-xs mt-1">Your conversations will appear here</p>
              </div>
            <% else %>
              <div class="space-y-2">
                <button
                  :for={history_item <- @chat_history}
                  type="button"
                  phx-click="load_history"
                  phx-value-id={history_item.id}
                  phx-target={@myself}
                  class="w-full text-left p-3 rounded-lg hover:bg-slate-50 transition-colors"
                >
                  <p class="text-sm font-medium text-slate-800 truncate">{history_item.preview}</p>
                  <p class="text-xs text-slate-400 mt-1">{format_history_date(history_item.timestamp)}</p>
                </button>
              </div>
            <% end %>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:messages, [])
     |> assign(:input_value, "")
     |> assign(:loading, false)
     |> assign(:selected_contact, nil)
     |> assign(:show_contact_picker, false)
     |> assign(:show_inline_picker, false)
     |> assign(:contact_suggestions, [])
     |> assign(:contact_search_query, "")
     |> assign(:searching_contacts, false)
     |> assign(:active_tab, :chat)
     |> assign(:collapsed, false)
     |> assign(:chat_history, [])
     |> assign(:session_started_at, DateTime.utc_now())}
  end

  @impl true
  def update(%{messages_append: message} = assigns, socket) do
    updated_messages = socket.assigns.messages ++ [message]

    {:ok,
     socket
     |> assign(Map.delete(assigns, :messages_append))
     |> assign(:messages, updated_messages)
     |> assign(:loading, false)}
  end

  def update(%{contact_suggestions: _suggestions} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:searching_contacts, false)}
  end

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:messages, fn -> [] end)
     |> assign_new(:input_value, fn -> "" end)
     |> assign_new(:loading, fn -> false end)
     |> assign_new(:selected_contact, fn -> nil end)
     |> assign_new(:show_contact_picker, fn -> false end)
     |> assign_new(:show_inline_picker, fn -> false end)
     |> assign_new(:contact_suggestions, fn -> [] end)
     |> assign_new(:contact_search_query, fn -> "" end)
     |> assign_new(:searching_contacts, fn -> false end)
     |> assign_new(:active_tab, fn -> :chat end)
     |> assign_new(:collapsed, fn -> false end)
     |> assign_new(:chat_history, fn -> [] end)
     |> assign_new(:session_started_at, fn -> DateTime.utc_now() end)}
  end

  # Event Handlers

  @impl true
  def handle_event("toggle_collapse", _params, socket) do
    {:noreply, assign(socket, collapsed: !socket.assigns.collapsed)}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    tab_atom = String.to_existing_atom(tab)
    {:noreply, assign(socket, active_tab: tab_atom)}
  end

  @impl true
  def handle_event("new_chat", _params, socket) do
    # Save current chat to history if there are messages
    chat_history =
      if Enum.any?(socket.assigns.messages) do
        history_item = %{
          id: System.unique_integer([:positive]),
          messages: socket.assigns.messages,
          preview: get_chat_preview(socket.assigns.messages),
          timestamp: socket.assigns.session_started_at
        }

        [history_item | socket.assigns.chat_history]
      else
        socket.assigns.chat_history
      end

    {:noreply,
     socket
     |> assign(:messages, [])
     |> assign(:input_value, "")
     |> assign(:selected_contact, nil)
     |> assign(:chat_history, chat_history)
     |> assign(:session_started_at, DateTime.utc_now())}
  end

  @impl true
  def handle_event("load_history", %{"id" => id}, socket) do
    id = String.to_integer(id)

    case Enum.find(socket.assigns.chat_history, &(&1.id == id)) do
      nil ->
        {:noreply, socket}

      history_item ->
        {:noreply,
         socket
         |> assign(:messages, history_item.messages)
         |> assign(:session_started_at, history_item.timestamp)
         |> assign(:active_tab, :chat)}
    end
  end

  @impl true
  def handle_event("open_contact_picker", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_contact_picker, true)
     |> assign(:contact_search_query, "")
     |> assign(:contact_suggestions, [])}
  end

  @impl true
  def handle_event("close_contact_picker", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_contact_picker, false)
     |> assign(:contact_search_query, "")
     |> assign(:contact_suggestions, [])
     |> assign(:searching_contacts, false)}
  end

  @impl true
  def handle_event("search_contacts", %{"value" => query}, socket) do
    query = String.trim(query)

    if byte_size(query) >= 2 do
      send(self(), {:search_crm_contacts, query, socket.assigns.id})
      {:noreply,
       socket
       |> assign(:contact_search_query, query)
       |> assign(:searching_contacts, true)}
    else
      {:noreply,
       socket
       |> assign(:contact_search_query, query)
       |> assign(:contact_suggestions, [])
       |> assign(:searching_contacts, false)}
    end
  end

  @impl true
  def handle_event("input_change", %{"message" => value}, socket) do
    # Check if user is typing @ to search for contacts (inline @ mention)
    if String.contains?(value, "@") && !socket.assigns.selected_contact do
      case Regex.run(~r/@(\w*)$/, value) do
        [_, query] when byte_size(query) >= 2 ->
          send(self(), {:search_crm_contacts, query, socket.assigns.id})
          {:noreply,
           socket
           |> assign(:input_value, value)
           |> assign(:show_inline_picker, true)
           |> assign(:searching_contacts, true)}

        [_, _query] ->
          # @ followed by less than 2 chars - show picker but no search yet
          {:noreply,
           socket
           |> assign(:input_value, value)
           |> assign(:show_inline_picker, true)
           |> assign(:contact_suggestions, [])
           |> assign(:searching_contacts, false)}

        _ ->
          # No @ at end of string
          {:noreply,
           socket
           |> assign(:input_value, value)
           |> assign(:show_inline_picker, false)
           |> assign(:contact_suggestions, [])}
      end
    else
      {:noreply,
       socket
       |> assign(:input_value, value)
       |> assign(:show_inline_picker, false)}
    end
  end

  @impl true
  def handle_event("select_contact", %{"id" => contact_id, "crm" => crm_type}, socket) do
    contact = Enum.find(socket.assigns.contact_suggestions, &(&1.id == contact_id && &1.crm_type == crm_type))

    if contact do
      # Remove the @ mention from input
      new_input = Regex.replace(~r/@\w*$/, socket.assigns.input_value, "")

      {:noreply,
       socket
       |> assign(:selected_contact, contact)
       |> assign(:input_value, String.trim(new_input))
       |> assign(:show_contact_picker, false)
       |> assign(:show_inline_picker, false)
       |> assign(:contact_suggestions, [])
       |> assign(:contact_search_query, "")
       |> assign(:searching_contacts, false)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_inline_contact", %{"id" => contact_id, "crm" => crm_type}, socket) do
    contact = Enum.find(socket.assigns.contact_suggestions, &(&1.id == contact_id && &1.crm_type == crm_type))

    if contact do
      # Replace the @query with the contact name (with emoji) in the input
      contact_name = contact.display_name || "#{contact.firstname} #{contact.lastname}"
      contact_mention = "🗣️#{contact_name}"
      new_input = Regex.replace(~r/@\w*$/, socket.assigns.input_value, contact_mention)

      {:noreply,
       socket
       |> assign(:selected_contact, contact)
       |> assign(:input_value, new_input)
       |> assign(:show_inline_picker, false)
       |> assign(:contact_suggestions, [])
       |> assign(:searching_contacts, false)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("clear_contact", _params, socket) do
    {:noreply, assign(socket, selected_contact: nil)}
  end

  @impl true
  def handle_event("insert_at_symbol", _params, socket) do
    new_input =
      if socket.assigns.input_value == "" do
        "@"
      else
        socket.assigns.input_value <> " @"
      end

    {:noreply,
     socket
     |> assign(:input_value, new_input)
     |> assign(:show_inline_picker, true)}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) do
    message = String.trim(message)

    if message == "" do
      {:noreply, socket}
    else
      contact = socket.assigns.selected_contact

      user_message = %{
        role: "user",
        content: message,
        contact: contact,
        crm_type: contact && contact.crm_type,
        timestamp: DateTime.utc_now(),
        sources: nil
      }

      socket =
        socket
        |> assign(:messages, socket.assigns.messages ++ [user_message])
        |> assign(:input_value, "")
        |> assign(:loading, true)

      if contact do
        send(self(), {:ask_crm_question, message, contact, socket.assigns.id})
        {:noreply, socket}
      else
        # No contact selected - provide a helpful response
        system_message = %{
          role: "assistant",
          content: "To get the best results, try adding context by mentioning a contact with @ or asking about a specific meeting.",
          contact: nil,
          crm_type: nil,
          timestamp: DateTime.utc_now(),
          sources: nil
        }

        socket =
          socket
          |> assign(:messages, socket.assigns.messages ++ [system_message])
          |> assign(:loading, false)

        {:noreply, socket}
      end
    end
  end

  # Helper Functions

  defp format_session_date(datetime) do
    now = DateTime.utc_now()

    time =
      datetime
      |> Calendar.strftime("%I:%M%P")
      |> String.replace(~r/^0/, "")

    date =
      if Date.compare(DateTime.to_date(datetime), DateTime.to_date(now)) == :eq do
        "Today"
      else
        Calendar.strftime(datetime, "%B %d, %Y")
      end

    "#{time} – #{date}"
  end

  defp format_history_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M%P")
  end

  defp get_chat_preview(messages) do
    case Enum.find(messages, &(&1.role == "user")) do
      nil -> "Empty conversation"
      msg -> String.slice(msg.content, 0, 50) <> if(String.length(msg.content) > 50, do: "...", else: "")
    end
  end

  defp render_ai_response(message) do
    # Return the content directly - styling is handled in the template
    message.content
  end
end
