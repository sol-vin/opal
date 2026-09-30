require "http/client"
require "json"
require "uuid"
require "base64"

module Opal
  module Tools
    # Uploads recorded .cast files to Asciinema.org and generates Markdown badges
    class DemoUploader
      API_URL       = "https://asciinema.org/api/asciicasts"
      ID_FILE       = "demos/.install_id"
      MANIFEST_FILE = "demos/manifest.json"

      record UploadResult,
        filename : String,
        title : String,
        cast_url : String,
        svg_url : String,
        cast_id : String

      def self.get_or_create_install_id : String
        if File.exists?(ID_FILE)
          File.read(ID_FILE).strip
        else
          id = UUID.random.to_s
          Dir.mkdir_p("demos") unless Dir.exists?("demos")
          File.write(ID_FILE, id)
          id
        end
      end

      def self.upload_file(filepath : String, install_id : String) : UploadResult
        filename = File.basename(filepath)
        puts "  ⬆ Uploading #{filename}..."

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

            puts "    ✓ Success: #{cast_url}"
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

      def self.upload_all
        install_id = get_or_create_install_id
        puts "🚀 Asciinema Installation ID: #{install_id}"
        puts "🔗 Account Claim URL: https://asciinema.org/connect/#{install_id}"
        puts

        casts = [
          "demos/01_form_wizard.cast",
          "demos/02_fuzzy_finder.cast",
          "demos/03_cluster_dashboard.cast",
          "demos/04_ghost_autocomplete.cast",
          "demos/05_cli_toolchain.cast",
        ]

        results = [] of UploadResult

        casts.each do |cast_path|
          unless File.exists?(cast_path)
            raise "File not found: #{cast_path}. Run 'crystal run tools/record_demos.cr' first."
          end
          res = upload_file(cast_path, install_id)
          results << res
        end

        manifest = {
          "install_id" => install_id,
          "claim_url"  => "https://asciinema.org/connect/#{install_id}",
          "demos"      => results.map do |r|
            {
              "filename" => r.filename,
              "title"    => r.title,
              "cast_url" => r.cast_url,
              "svg_url"  => r.svg_url,
              "cast_id"  => r.cast_id,
              "markdown" => "[![asciicast](#{r.svg_url})](#{r.cast_url})",
            }
          end,
        }

        File.write(MANIFEST_FILE, manifest.to_pretty_json)
        puts "\n📄 Saved manifest to #{MANIFEST_FILE}"
        puts "\n🎉 All demos uploaded successfully!"
      end
    end
  end
end

Opal::Tools::DemoUploader.upload_all
