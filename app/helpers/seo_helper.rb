module SeoHelper
  def canonical_url
    request.original_url.split("?").first
  end
end
