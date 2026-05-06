module ApplicationHelper
  def flash_bootstrap_class(type)
    { "notice" => "success", "alert" => "danger", "info" => "info", "warning" => "warning" }
      .fetch(type.to_s, "secondary")
  end

  def render_markdown(text)
    renderer = Redcarpet::Render::HTML.new(safe_links_only: true, no_styles: true)
    markdown = Redcarpet::Markdown.new(renderer, autolink: true, tables: true, fenced_code_blocks: true)
    markdown.render(text.to_s).html_safe
  end
end
