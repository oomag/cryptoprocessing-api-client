module Cryptoprocessing
  # Event Machine
  class EmHTTPClient < APIClient
    private

    def http_verb(method, path, body = nil, headers = {})
      if !EventMachine.reactor_running?
        EM.run do
          request(method, path, body) do |resp|
            yield(resp)
            EM.stop
          end
        end
      else
        headers['Content-Type'] = 'application/json'
        headers['User-Agent'] = "cryptoprocessing/ruby-em/#{Cryptoprocessing::VERSION}"
        auth_headers(method, path, body).each do |key, val|
          headers[key] = val
        end

        ssl_opts =  { cert_chain_file: File.expand_path(File.join(File.dirname(__FILE__), 'ca-cryptoprocessing.crt')),
                      verify_peer: true }

        case method
        when 'GET'
          req = EM::HttpRequest.new(@api_uri).get(path: path, head: headers, body: body, ssl: ssl_opts)
        when 'POST'
          req = EM::HttpRequest.new(@api_uri).put(path: path, head: headers, body: body, ssl: ssl_opts)
        when 'POST'
          req = EM::HttpRequest.new(@api_uri).post(path: path, head: headers, body: body, ssl: ssl_opts)
        when 'DELETE'
          req = EM::HttpRequest.new(@api_uri).delete(path: path, head: headers, ssl: ssl_opts)
        else raise
        end
        req.callback do |resp|
          out = EMHTTPResponse.new(resp)
          Cryptoprocessing::check_response_status(out)
          yield(out)
        end
        req.errback do |resp|
          raise APIError, "#{method} #{@api_uri}#{path}: #{resp.error}"
        end
      end
  end

  # EM-Http response object
  class EMHTTPResponse < APIResponse
    def body
      JSON.parse(@response.response)
    end

    def data
      body['data']
    end

    def body=(body)
      @response.response = body.to_json
    end

    def headers
      out = @response.response_header.map do |key, val|
        [key.upcase.gsub('_', '-'), val]
      end
      out.to_h
    end

    def status
      @response.response_header.status
    end
  end
end
