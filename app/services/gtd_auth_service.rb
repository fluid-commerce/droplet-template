require "openssl"
require "base64"

class GtdAuthService
  def initialize(company)
    @company = company
    settings = company.settings
    @username = settings["username"]
    @password = settings["password"]
    @hmac_key = settings["hmac_key"]
  end

  def generate_auth_header(request_suffix = "calcTax/doc")
    timestamp = Time.now.utc.iso8601
    security_subject = "#{@username}#{@password}"
    twe_url_path_body = "/Twe/api/rest/#{request_suffix}"

    plain_string_signature = determine_plain_string_hmac_signature(
      timestamp: timestamp,
      security_subject: security_subject,
      twe_url_path_body: twe_url_path_body
    )

    hmac_digest = generate_hmac_digest(plain_string_signature)

    {
      auth_header: "TAX #{@username}:#{hmac_digest}",
      timestamp: timestamp,
    }
  end

private

  def determine_plain_string_hmac_signature(timestamp:, security_subject:, twe_url_path_body:)
    "POST" + "application/json" + timestamp + twe_url_path_body + security_subject
  end

  def generate_hmac_digest(data)
    # Use SHA1 as specified in the JS code
    digest = OpenSSL::HMAC.digest("sha1", @hmac_key, data)
    Base64.strict_encode64(digest)
  end
end
