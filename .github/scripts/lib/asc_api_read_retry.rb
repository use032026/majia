# frozen_string_literal: true

require "uri"

module MajiaCI
  # Recover transient read failures without replaying App Store mutations.
  module ASCAPIReadRetry
    private

    def request(method, path, **options)
      attempts = 0
      begin
        attempts += 1
        super
      rescue StandardError => error
        raise unless method.to_s.downcase == "get" && error.respond_to?(:status) &&
                     [500, 502, 503, 504].include?(error.status) && attempts < 4

        warn "ASC read retry: #{method.to_s.upcase} #{URI(path).path} HTTP #{error.status} attempt #{attempts}/4"
        sleep([2, 4, 8].fetch(attempts - 1))
        retry
      end
    end
  end
end
