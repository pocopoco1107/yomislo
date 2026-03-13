class Rack::Attack
  throttle("req/ip", limit: 60, period: 1.minute) do |req|
    req.ip
  end

  throttle("votes/ip", limit: 50, period: 1.day) do |req|
    if req.path.start_with?("/votes") && %w[POST PATCH PUT].include?(req.request_method)
      req.ip
    end
  end

  throttle("comments/ip", limit: 10, period: 1.hour) do |req|
    if req.path == "/comments" && req.post?
      req.ip
    end
  end

  throttle("reports/ip", limit: 10, period: 1.hour) do |req|
    if req.path == "/reports" && req.post?
      req.ip
    end
  end

  throttle("feedbacks/ip", limit: 5, period: 1.hour) do |req|
    if req.path == "/feedbacks" && req.post?
      req.ip
    end
  end

  throttle("shop_events/ip", limit: 5, period: 1.hour) do |req|
    if req.path.match?(%r{/shops/.+/events}) && req.post?
      req.ip
    end
  end

  throttle("play_records/ip", limit: 20, period: 1.hour) do |req|
    if req.path.start_with?("/play_records") && %w[POST PATCH PUT DELETE].include?(req.request_method)
      req.ip
    end
  end

  self.throttled_responder = lambda do |req|
    match_data = req.env["rack.attack.match_data"]
    now = Time.now.utc
    headers = {
      "Content-Type" => "text/plain",
      "Retry-After" => (match_data[:period] - (now.to_i % match_data[:period])).to_s
    }
    [429, headers, ["リクエスト制限に達しました。しばらく待ってからお試しください。\n"]]
  end
end
