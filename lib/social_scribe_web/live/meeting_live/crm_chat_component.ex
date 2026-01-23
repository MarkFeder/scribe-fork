defmodule SocialScribeWeb.MeetingLive.CrmChatComponent do
  @moduledoc """
  A chat interface component for asking questions about CRM contacts.
  Supports both HubSpot and Salesforce contacts with @ mention tagging.
  """
  use SocialScribeWeb, :live_component

  import SocialScribeWeb.ModalComponents, only: [avatar: 1]

  alias SocialScribe.AIContentGeneratorApi

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-[500px] bg-white rounded-2xl shadow-lg overflow-hidden">
      <!-- Header -->
      <div class="px-6 py-4 border-b border-slate-200 bg-gradient-to-r from-slate-50 to-white">
        <h3 class="text-lg font-semibold text-slate-800">CRM Assistant</h3>
        <p class="text-sm text-slate-500">Ask questions about your contacts</p>
      </div>

      <!-- Messages Area -->
      <div class="flex-1 overflow-y-auto p-4 space-y-4" id="chat-messages" phx-hook="ScrollToBottom">
        <%= if Enum.empty?(@messages) do %>
          <div class="flex flex-col items-center justify-center h-full text-center px-4">
            <div class="w-16 h-16 bg-slate-100 rounded-full flex items-center justify-center mb-4">
              <.icon name="hero-chat-bubble-left-right" class="w-8 h-8 text-slate-400" />
            </div>
            <h4 class="text-slate-700 font-medium mb-2">Start a conversation</h4>
            <p class="text-sm text-slate-500 max-w-sm">
              Type @ to mention a contact, then ask any question about them.
              I'll look up their information in your connected CRM.
            </p>
          </div>
        <% else %>
          <div :for={message <- @messages} class={["flex", message.role == "user" && "justify-end"]}>
            <div class={[
              "max-w-[80%] rounded-2xl px-4 py-3",
              message.role == "user" && "bg-indigo-600 text-white",
              message.role == "assistant" && "bg-slate-100 text-slate-800",
              message.role == "system" && "bg-amber-50 text-amber-800 border border-amber-200"
            ]}>
              <%= if message.contact do %>
                <div class="flex items-center gap-2 mb-2 pb-2 border-b border-slate-200/50">
                  <.avatar firstname={message.contact.firstname} lastname={message.contact.lastname} size={:sm} />
                  <span class="text-xs font-medium opacity-80">
                    Re: {message.contact.display_name}
                  </span>
                  <span class={[
                    "text-xs px-2 py-0.5 rounded-full",
                    message.crm_type == "hubspot" && "bg-orange-100 text-orange-700",
                    message.crm_type == "salesforce" && "bg-blue-100 text-blue-700"
                  ]}>
                    {String.capitalize(message.crm_type || "")}
                  </span>
                </div>
              <% end %>
              <p class="text-sm whitespace-pre-wrap">{message.content}</p>
              <p class={[
                "text-xs mt-2 opacity-60",
                message.role == "user" && "text-right"
              ]}>
                {format_time(message.timestamp)}
              </p>
            </div>
          </div>

          <%= if @loading do %>
            <div class="flex justify-start">
              <div class="bg-slate-100 rounded-2xl px-4 py-3">
                <div class="flex items-center gap-2">
                  <div class="flex gap-1">
                    <div class="w-2 h-2 bg-slate-400 rounded-full animate-bounce" style="animation-delay: 0ms"></div>
                    <div class="w-2 h-2 bg-slate-400 rounded-full animate-bounce" style="animation-delay: 150ms"></div>
                    <div class="w-2 h-2 bg-slate-400 rounded-full animate-bounce" style="animation-delay: 300ms"></div>
                  </div>
                  <span class="text-sm text-slate-500">Thinking...</span>
                </div>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>

      <!-- Contact Suggestions Dropdown -->
      <div :if={@show_contact_suggestions && Enum.any?(@contact_suggestions)} class="relative">
        <div class="absolute bottom-0 left-4 right-4 bg-white border border-slate-200 rounded-lg shadow-lg max-h-48 overflow-y-auto z-10">
          <div class="p-2">
            <p class="text-xs text-slate-500 px-2 pb-2">Select a contact</p>
            <button
              :for={contact <- @contact_suggestions}
              type="button"
              phx-click="select_contact"
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
      </div>

      <!-- Input Area -->
      <div class="px-4 py-3 border-t border-slate-200 bg-slate-50">
        <%= if @selected_contact do %>
          <div class="flex items-center gap-2 mb-2 px-3 py-2 bg-white rounded-lg border border-slate-200">
            <.avatar firstname={@selected_contact.firstname} lastname={@selected_contact.lastname} size={:sm} />
            <span class="text-sm font-medium text-slate-700">{@selected_contact.display_name}</span>
            <span class={[
              "text-xs px-2 py-0.5 rounded-full",
              @selected_contact.crm_type == "hubspot" && "bg-orange-100 text-orange-700",
              @selected_contact.crm_type == "salesforce" && "bg-blue-100 text-blue-700"
            ]}>
              {String.capitalize(@selected_contact.crm_type)}
            </span>
            <button
              type="button"
              phx-click="clear_selected_contact"
              phx-target={@myself}
              class="ml-auto text-slate-400 hover:text-slate-600"
            >
              <.icon name="hero-x-mark" class="w-4 h-4" />
            </button>
          </div>
        <% end %>

        <form phx-submit="send_message" phx-change="input_change" phx-target={@myself} class="flex gap-2">
          <div class="flex-1 relative">
            <input
              type="text"
              name="message"
              value={@input_value}
              placeholder={if @selected_contact, do: "Ask about #{@selected_contact.display_name}...", else: "Type @ to mention a contact..."}
              autocomplete="off"
              phx-debounce="100"
              class="w-full px-4 py-3 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
            />
          </div>
          <button
            type="submit"
            disabled={@loading || String.trim(@input_value) == ""}
            class="px-4 py-3 bg-indigo-600 text-white rounded-xl hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            <.icon name="hero-paper-airplane" class="w-5 h-5" />
          </button>
        </form>
      </div>
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
     |> assign(:show_contact_suggestions, false)
     |> assign(:contact_suggestions, [])}
  end

  @impl true
  def update(%{messages_append: message} = assigns, socket) do
    # Append a new message to the existing messages
    updated_messages = socket.assigns.messages ++ [message]

    {:ok,
     socket
     |> assign(Map.delete(assigns, :messages_append))
     |> assign(:messages, updated_messages)
     |> assign(:loading, false)}
  end

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:messages, fn -> [] end)
     |> assign_new(:input_value, fn -> "" end)
     |> assign_new(:loading, fn -> false end)
     |> assign_new(:selected_contact, fn -> nil end)
     |> assign_new(:show_contact_suggestions, fn -> false end)
     |> assign_new(:contact_suggestions, fn -> [] end)}
  end

  @impl true
  def handle_event("input_change", %{"message" => value}, socket) do
    # Check if user is typing @ to search for contacts
    if String.contains?(value, "@") && !socket.assigns.selected_contact do
      # Extract the search query after @
      case Regex.run(~r/@(\w*)$/, value) do
        [_, query] when byte_size(query) >= 2 ->
          # Search for contacts
          send(self(), {:search_crm_contacts, query, socket.assigns.id})
          {:noreply, assign(socket, input_value: value, show_contact_suggestions: true)}

        _ ->
          {:noreply, assign(socket, input_value: value, show_contact_suggestions: false, contact_suggestions: [])}
      end
    else
      {:noreply, assign(socket, input_value: value, show_contact_suggestions: false)}
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
       |> assign(:show_contact_suggestions, false)
       |> assign(:contact_suggestions, [])}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("clear_selected_contact", _params, socket) do
    {:noreply, assign(socket, selected_contact: nil)}
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
        timestamp: DateTime.utc_now()
      }

      socket =
        socket
        |> assign(:messages, socket.assigns.messages ++ [user_message])
        |> assign(:input_value, "")
        |> assign(:loading, true)

      if contact do
        send(self(), {:ask_crm_question, message, contact, socket.assigns.id})
      else
        # No contact selected - prompt user to select one
        system_message = %{
          role: "system",
          content: "Please select a contact by typing @ followed by their name to search.",
          contact: nil,
          crm_type: nil,
          timestamp: DateTime.utc_now()
        }

        socket =
          socket
          |> assign(:messages, socket.assigns.messages ++ [system_message])
          |> assign(:loading, false)

        {:noreply, socket}
      end

      {:noreply, socket}
    end
  end

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%H:%M")
  end
end
