# frozen_string_literal: true

require "base64"
require "json"
require "openssl"

module MajiaCI
  module ASCPrivateKey
    module_function

    def normalize_p8(secret, error_class:, required_message: "ASC_API_KEY_P8 is required")
      compact = secret.to_s.strip
      raise error_class, required_message if compact.empty?

      if compact.start_with?("\"") && compact.end_with?("\"")
        decoded_json = JSON.parse(compact)
        compact = decoded_json.strip if decoded_json.is_a?(String)
      end
      compact = compact.sub(/\AASC_API_KEY_P8\s*=\s*/, "").strip
      if compact.match?(/\A-----BEGIN (?:EC )?PRIVATE KEY-----/) && compact.include?("\\n")
        compact = compact.gsub("\\r\\n", "\n").gsub("\\n", "\n").strip
      end

      pem_match = compact.match(
        /\A-----BEGIN ((?:EC )?PRIVATE KEY)-----(.*?)-----END \1-----\z/m
      )
      candidates = if pem_match
                     label = pem_match[1]
                     body = pem_match[2].gsub(/\s+/, "")
                     unless body.match?(/\A[A-Za-z0-9+\/]+={0,2}\z/)
                       raise error_class, "ASC_API_KEY_P8 PEM body must be valid Base64"
                     end
                     lines = body.scan(/.{1,64}/)
                     canonical_pem = "-----BEGIN #{label}-----\n#{lines.join("\n")}\n-----END #{label}-----\n"
                     [["PEM", canonical_pem]]
                   elsif compact.include?("-----BEGIN") || compact.include?("-----END")
                     raise error_class, "ASC_API_KEY_P8 PEM header or footer is incomplete"
                   else
                     decoded = Base64.strict_decode64(compact.gsub(/\s+/, ""))
                     values = [["Base64", decoded]]
                     decoded_compact = decoded.to_s.gsub(/\s+/, "")
                     if decoded.ascii_only? && decoded_compact.match?(/\A[A-Za-z0-9+\/_-]+={0,2}\z/)
                       begin
                         values << ["double Base64", Base64.strict_decode64(decoded_compact.tr("-_", "+/"))]
                       rescue ArgumentError
                         # The first decoded value remains the only candidate.
                       end
                     end
                     values
                   end

      candidates.each do |_format, key_bytes|
        begin
          key = OpenSSL::PKey.read(key_bytes)
          next unless key.is_a?(OpenSSL::PKey::EC) && key.private? && key.group.curve_name == "prime256v1"

          return Base64.strict_encode64(key_bytes)
        rescue OpenSSL::PKey::PKeyError
          next
        end
      end

      formats = candidates.map(&:first).join(" or ")
      raise error_class, "ASC_API_KEY_P8 must contain a P-256 EC private key in #{formats} form"
    rescue ArgumentError, JSON::ParserError => e
      raise error_class, "ASC_API_KEY_P8 is invalid: #{e.message}"
    end

    def read_p8(secret, error_class:, required_message: "ASC_API_KEY_P8 is required")
      encoded = normalize_p8(secret, error_class: error_class, required_message: required_message)
      OpenSSL::PKey.read(Base64.strict_decode64(encoded))
    end
  end
end
