#!/usr/bin/env ruby
require "mobilis"

# Chaos Management System
#

# Since this is the first real client app, documenting 'things' is needed.

# Rails + Hotwire + Tailwind demo using vendored retroui-rails components.

Mobilis::DSL.generate("generate") do
  otel_collector("otel-collector")
  grafana("grafana")
  jaeger("jaeger")
  logs = loki("loki")
  prometheus("prometheus")
  alloy("alloy", loki: logs)

  connect from: "grafana",        to: "loki"
  connect from: "grafana",        to: "prometheus"
  connect from: "otel-collector", to: "jaeger"
  connect from: "prometheus",     to: "otel-collector"

  rails("chaosmanagement", primary_database: postgres("chaosmanagement-db")) do |svc|
    svc.use_rspec!
    svc.use_tailwind!
    svc.use_uuid_primary_keys!
    svc.add_gem(
      "retroui-rails",
      git: "https://github.com/meleneth/retroui-rails.git",
      branch: "main",
      require_name: "retro_ui/rails"
    )

    svc.add_rails_model("user") do |m|
      m.string "name"
      m.string "avatar_url"
    end
    svc.add_rails_model("meeting")
    svc.add_rails_model("agenda")
    svc.add_rails_model("proposal")
    svc.add_rails_model("agreement")

    svc.write_file("app/assets/tailwind/application.css", <<~CSS)
      @import "tailwindcss";
      @import "../stylesheets/retro_ui/theme.css";

      @source "../../views/**/*.erb";
      @source "../../components/**/*.rb";
      @source "../../components/**/*.erb";
      @source "../../javascript/**/*.js";

      @theme {
        --color-background: hsl(var(--background));
        --color-foreground: hsl(var(--foreground));
        --color-card: hsl(var(--card));
        --color-card-foreground: hsl(var(--card-foreground));
        --color-primary: hsl(var(--primary));
        --color-primary-foreground: hsl(var(--primary-foreground));
        --color-secondary: hsl(var(--secondary));
        --color-secondary-foreground: hsl(var(--secondary-foreground));
        --color-muted: hsl(var(--muted));
        --color-muted-foreground: hsl(var(--muted-foreground));
        --color-accent: hsl(var(--accent));
        --color-accent-foreground: hsl(var(--accent-foreground));
        --color-destructive: hsl(var(--destructive));
        --color-destructive-foreground: hsl(var(--destructive-foreground));
        --color-border: hsl(var(--border));
        --shadow-xs: 1px 1px 0 0 hsl(var(--border));
        --shadow-sm: 2px 2px 0 0 hsl(var(--border));
        --shadow: 3px 3px 0 0 hsl(var(--border));
        --shadow-md: 4px 4px 0 0 hsl(var(--border));
        --shadow-lg: 6px 6px 0 0 hsl(var(--border));
        --shadow-xl: 8px 8px 0 0 hsl(var(--border));
        --font-head: ui-sans-serif, system-ui, sans-serif;
      }

      body {
        margin: 0;
        background: hsl(var(--background));
        color: hsl(var(--foreground));
        font-family: ui-sans-serif, system-ui, sans-serif;
      }

      .demo-shell {
        max-width: 1120px;
        margin: 0 auto;
        padding: 32px;
      }

      .demo-header,
      .demo-row {
        display: flex;
        flex-wrap: wrap;
        gap: 12px;
        align-items: center;
      }

      .demo-header {
        justify-content: space-between;
        align-items: flex-start;
      }

      .demo-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
        gap: 18px;
        align-items: start;
      }

      .demo-stack {
        display: grid;
        gap: 12px;
      }

      .demo-section {
        margin-top: 32px;
        padding-top: 24px;
        border-top: 2px solid hsl(var(--border));
      }
    CSS

    svc.write_file("app/controllers/retro_ui_demo_controller.rb", <<~RUBY)
      class RetroUiDemoController < ApplicationController
        def index
        end
      end
    RUBY

    svc.write_file("config/routes.rb", <<~RUBY)
      Rails.application.routes.draw do
        root "retro_ui_demo#index"
      end
    RUBY

    svc.write_file("app/views/retro_ui_demo/index.html.erb", <<~ERB)
      <main class="demo-shell">
        <div class="demo-header">
          <div>
            <%= render RetroUI::TypographyComponent.new(as: :h1, text: "Chaos Management") %>
            <%= render RetroUI::TypographyComponent.new(as: :lead, text: "Generated Rails, Hotwire, Tailwind, and vendored RetroUI components.") %>
          </div>

          <div class="demo-row">
            <%= render RetroUI::BadgeComponent.new(label: "Vendored", variant: :secondary) %>
            <%= render RetroUI::ButtonComponent.new(label: "Primary Action") %>
          </div>
        </div>

        <section class="demo-section">
          <%= render RetroUI::TypographyComponent.new(as: :h2, text: "Actions") %>
          <div class="demo-row">
            <%= render RetroUI::ButtonComponent.new(label: "Default") %>
            <%= render RetroUI::ButtonComponent.new(label: "Secondary", variant: :secondary) %>
            <%= render RetroUI::ButtonComponent.new(label: "Outline", variant: :outline) %>
            <%= render RetroUI::ButtonComponent.new(label: "Danger", variant: :destructive) %>
          </div>
        </section>

        <section class="demo-section">
          <%= render RetroUI::TypographyComponent.new(as: :h2, text: "Cards And Alerts") %>
          <div class="demo-grid">
            <%= render RetroUI::CardComponent.new(html_options: { class: "w-full" }) do %>
              <%= render RetroUI::CardHeaderComponent.new do %>
                <%= render RetroUI::CardTitleComponent.new do %>
                  Incident Room
                <% end %>
                <%= render RetroUI::CardDescriptionComponent.new do %>
                  Component source lives in app/components/retro_ui after vendoring.
                <% end %>
              <% end %>
              <%= render RetroUI::CardContentComponent.new do %>
                <div class="demo-row">
                  <%= render RetroUI::BadgeComponent.new(label: "Open") %>
                  <%= render RetroUI::BadgeComponent.new(label: "Escalated", variant: :destructive) %>
                </div>
              <% end %>
            <% end %>

            <div class="demo-stack">
              <%= render RetroUI::AlertComponent.new do %>
                <%= render RetroUI::AlertTitleComponent.new do %>
                  Tailwind active
                <% end %>
                <%= render RetroUI::AlertDescriptionComponent.new do %>
                  The generated Tailwind entrypoint imports the vendored RetroUI theme.
                <% end %>
              <% end %>

              <%= render RetroUI::AlertComponent.new(variant: :destructive) do %>
                <%= render RetroUI::AlertTitleComponent.new do %>
                  Demo alert
                <% end %>
                <%= render RetroUI::AlertDescriptionComponent.new do %>
                  Destructive variants are also rendered from vendored components.
                <% end %>
              <% end %>
            </div>
          </div>
        </section>

        <section class="demo-section">
          <%= render RetroUI::TypographyComponent.new(as: :h2, text: "Hotwire Components") %>
          <div class="demo-grid">
            <%= render RetroUI::CardComponent.new(html_options: { class: "w-full" }) do %>
              <%= render RetroUI::CardHeaderComponent.new do %>
                <%= render RetroUI::CardTitleComponent.new do %>
                  Tabs
                <% end %>
              <% end %>
              <%= render RetroUI::CardContentComponent.new do %>
                <%= render RetroUI::TabsComponent.new(default_value: "summary") do %>
                  <%= render RetroUI::TabsListComponent.new do %>
                    <%= render RetroUI::TabsTriggerComponent.new(value: "summary", text: "Summary") %>
                    <%= render RetroUI::TabsTriggerComponent.new(value: "details", text: "Details") %>
                  <% end %>
                  <%= render RetroUI::TabsContentComponent.new(value: "summary") do %>
                    Active incidents, quiet UI, and no React dependency.
                  <% end %>
                  <%= render RetroUI::TabsContentComponent.new(value: "details") do %>
                    Stimulus controllers are loaded from app/javascript/controllers/retro_ui.
                  <% end %>
                <% end %>
              <% end %>
            <% end %>

            <%= render RetroUI::CardComponent.new(html_options: { class: "w-full" }) do %>
              <%= render RetroUI::CardHeaderComponent.new do %>
                <%= render RetroUI::CardTitleComponent.new do %>
                  Overlays
                <% end %>
              <% end %>
              <%= render RetroUI::CardContentComponent.new do %>
                <div class="demo-row">
                  <%= render RetroUI::DialogComponent.new do %>
                    <%= render RetroUI::DialogTriggerComponent.new(label: "Open Dialog") %>
                    <%= render RetroUI::DialogContentComponent.new do %>
                      <%= render RetroUI::DialogCloseComponent.new %>
                      <%= render RetroUI::DialogHeaderComponent.new do %>
                        <%= render RetroUI::DialogTitleComponent.new(text: "Hotwire dialog") %>
                        <%= render RetroUI::DialogDescriptionComponent.new(text: "Opened by a vendored Stimulus controller.") %>
                      <% end %>
                      <%= render RetroUI::DialogFooterComponent.new do %>
                        <%= render RetroUI::ButtonComponent.new(label: "Acknowledge", size: :sm) %>
                      <% end %>
                    <% end %>
                  <% end %>

                  <%= render RetroUI::DropdownMenuComponent.new do %>
                    <%= render RetroUI::DropdownMenuTriggerComponent.new(label: "Menu") %>
                    <%= render RetroUI::DropdownMenuContentComponent.new do %>
                      <%= render RetroUI::DropdownMenuItemComponent.new(text: "Assign") %>
                      <%= render RetroUI::DropdownMenuItemComponent.new(text: "Escalate") %>
                      <%= render RetroUI::DropdownMenuItemComponent.new(text: "Resolve") %>
                    <% end %>
                  <% end %>

                  <%= render RetroUI::PopoverComponent.new do %>
                    <%= render RetroUI::PopoverTriggerComponent.new(label: "Popover") %>
                    <%= render RetroUI::PopoverContentComponent.new do %>
                      This content is toggled by Hotwire/Stimulus.
                    <% end %>
                  <% end %>
                </div>

                <p>
                  Hover
                  <%= render RetroUI::TooltipComponent.new do %>
                    <%= render RetroUI::TooltipTriggerComponent.new(text: "this label") %>
                    <%= render RetroUI::TooltipContentComponent.new(text: "Tooltip from vendored RetroUI") %>
                  <% end %>
                  for a tooltip.
                </p>
              <% end %>
            <% end %>
          </div>
        </section>

        <section class="demo-section">
          <%= render RetroUI::TypographyComponent.new(as: :h2, text: "Forms") %>
          <div class="demo-grid">
            <div class="demo-stack">
              <%= render RetroUI::LabelComponent.new(text: "Incident name", for_id: "incident_name") %>
              <%= render RetroUI::InputComponent.new(name: "incident[name]", html_options: { id: "incident_name", placeholder: "Database latency" }) %>
              <%= render RetroUI::LabelComponent.new(text: "Notes", for_id: "incident_notes") %>
              <%= render RetroUI::TextareaComponent.new(name: "incident[notes]", html_options: { id: "incident_notes", placeholder: "What changed?" }) %>
            </div>

            <div class="demo-stack">
              <label class="demo-row">
                <%= render RetroUI::CheckboxComponent.new(name: "incident[confirmed]", checked: true) %>
                Confirmed
              </label>
              <label class="demo-row">
                <%= render RetroUI::SwitchComponent.new(name: "incident[paging]", checked: true) %>
                Paging enabled
              </label>
              <%= render RetroUI::SelectComponent.new(name: "incident[severity]", options: [["Low", "low"], ["Medium", "medium"], ["High", "high"]], selected: "medium") %>
            </div>
          </div>
        </section>

        <%= render RetroUI::ToastViewportComponent.new do %>
          <%= render RetroUI::ToastComponent.new(duration: 0) do %>
            <%= render RetroUI::ToastTitleComponent.new(text: "Generated demo ready") %>
            <%= render RetroUI::ToastDescriptionComponent.new(text: "This toast is Hotwire-backed.") %>
            <%= render RetroUI::ToastCloseComponent.new %>
          <% end %>
        <% end %>
      </main>
    ERB

    svc.run_command(
      "bin/rails generate retro_ui:vendor --force",
      "vendor RetroUI Rails components"
    )
  end
  connect from: "chaosmanagement", to: "otel-collector"
end
