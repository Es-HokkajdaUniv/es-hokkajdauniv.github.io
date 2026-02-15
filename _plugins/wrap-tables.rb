Jekyll::Hooks.register :pages, :post_render do |page|
  next unless page.output_ext == ".html"

  page.output = page.output.gsub(/<table(.*?)>(.*?)<\/table>/m) do
    "<div class=\"table-container\"><table#{$1}>#{$2}</table></div>"
  end
end

Jekyll::Hooks.register :posts, :post_render do |post|
  next unless post.output_ext == ".html"

  post.output = post.output.gsub(/<table(.*?)>(.*?)<\/table>/m) do
    "<div class=\"table-container\"><table#{$1}>#{$2}</table></div>"
  end
end
