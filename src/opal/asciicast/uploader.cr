require "http/client"
require "json"
require "uuid"
require "base64"

module Opal
  module Asciicast
    # Client for uploading .cast recordings to Asciinema.org.
    class Uploader
      API_URL       = "https://asciinema.org/api/asciicasts"
      ID_FILE       = "demos/.install_id"
      MANIFEST_FILE = "demos/manifest.json"

      record UploadResult,
        filename : String,
        title : String,
        cast_url : String,
        svg_url : String,
        cast_id : String

      # Retrieves an existing Asciinema install ID from disk or generates a new one.
      def self.get_or_create_install_id(id_path : String = ID_FILE) : String
        if File.exists?(id_path)
          File.read(id_path).strip
        else
          id = UUID.random.to_s
          dir = File.dirname(id_path)
          Dir.mkdir_p(dir) unless Dir.exists?(dir)
          File.write(id_path, id)
          id
        end
      end

      # Uploads a single .cast file to Asciinema.org using the Asciinema API.
      def self.upload_file(filepath : String, install_id : String, verbose : Bool = false) : UploadResult
        filename = File.basename(filepath)
        puts "  ⬆ Uploading #{filename}..." if verbose

        content = File.read(filepath)

        body_io = IO::Memory.new
        boundary = "----AsciinemaUploadBoundary#{UUID.random.to_s.gsub("-", "")}"

        body_io << "--" << boundary << "\r\n"
        body_io << "Content-Disposition: form-data; name=\"asciicast\"; filename=\"" << filename << "\"\r\n"
        body_io << "Content-Type: application/octet-stream\r\n\r\n"
        body_io << content
        body_io << "\r\n--" << boundary << "--\r\n"

        auth_header = "Basic " + Base64.strict_encode("user:#{install_id}")
        headers = HTTP::Headers{
          "Content-Type"   => "multipart/form-data; boundary=#{boundary}",
          "Content-Length" => body_io.size.to_s,
          "Authorization"  => auth_header,
          "User-Agent"     => "OpalTUI/0.1.0",
        }

        uri = URI.parse(API_URL)
        client = HTTP::Client.new(uri)
        begin
          response = client.post(uri.path, headers: headers, body: body_io.to_s)

          if response.status_code == 201
            json = JSON.parse(response.body)
            cast_url = json["url"].as_s
            title = json["title"]?.try(&.as_s) || filename
            svg_url = "#{cast_url}.svg"
            cast_id = cast_url.split("/").last

            puts "    ✓ Success: #{cast_url}" if verbose
            UploadResult.new(
              filename: filename,
              title: title,
              cast_url: cast_url,
              svg_url: svg_url,
              cast_id: cast_id
            )
          else
            raise "Upload failed for #{filename} (HTTP #{response.status_code}): #{response.body}"
          end
        ensure
          client.close
        end
      end
    end
  end
end
