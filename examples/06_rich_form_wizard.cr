require "../src/opal"

# Showcases Opal's Multi-Field Form DSL with live inline validation and tab navigation.
puts Opal.style.bold.foreground(Opal::Color.hex("#CBA6F7")).render("\n💎 Opal Multi-Field Interactive Form Wizard\n")

result = Opal.form("New Microservice Configuration") do |f|
  f.text "name", "Service Name:", default: "auth-gateway", required: true
  f.text "port", "HTTP Port:", default: "8080"
  f.password "api_key", "Cluster Secret Key:", min_length: 6, default: "secret123"
  f.select "runtime", "Target Runtime:", ["Crystal 1.15", "Docker Alpine", "Bare Metal"]
  f.multi_select "features", "Enabled Features:", ["OpenTelemetry", "Redis Caching", "Rate Limiter", "GraphQL"], selected: ["OpenTelemetry", "Redis Caching"]
  f.confirm "deploy_now", "Auto-deploy to staging on save?", default: true

  f.validate "port" do |val|
    (val.to_i? && (1024..65535).includes?(val.to_i)) ? nil : "Must be a valid port number between 1024 and 65535"
  end
end

if res = result
  puts Opal.style.bold.foreground(Opal::Color.green).render("\n✔ Configuration Captured Successfully!")
  res.each do |k, v|
    puts "  #{Opal.style.bold.render(k.ljust(15))}: #{v}"
  end
else
  puts Opal.style.foreground(Opal::Color.yellow).render("\nForm wizard was cancelled.")
end
