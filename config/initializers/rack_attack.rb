class Rack::Attack
  throttle("req/ip", limit: 60, period: 1.minute) do |req|
    req.ip
  end

  throttle("votes/ip", limit: 50, period: 1.day) do |req|
    if req.path == "/votes" && req.post?
      req.ip
    end
  end

  throttle("comments/ip", limit: 10, period: 1.hour) do |req|
    if req.path == "/comments" && req.post?
      req.ip
    end
  end

  self.throttled_responder = lambda do |matched, period, limit, req|
    now = Time.now.utc
    match_data = req.env["rack.attack.match_data"]
    headers = {
      "Content-Type" => "text/plain",
      "Retry-After" => (match_data[:period] - (now.to_i % match_data[:period])).to_s
    }
    [429, headers, ["リクエスト制限に達しました。しばらく待ってからお試しください。\n"]]
  end
end
