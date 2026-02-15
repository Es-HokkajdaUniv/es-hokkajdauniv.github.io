Jekyll::Hooks.register :site, :after_init do |site|
  site.config['url'] = ENV['CF_PAGES_URL'] if ENV['CF_PAGES_URL']
end
