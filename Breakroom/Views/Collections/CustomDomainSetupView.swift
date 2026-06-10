import SwiftUI

struct CustomDomainSetupView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Use Your Own Domain")
                        .font(.title2.bold())
                    Text("Point a domain you own at your Prosaurus store so customers can find you at your own web address.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // How it works
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How it works")
                            .font(.headline)

                        Text("Your store lives at a Prosaurus URL like:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("https://www.prosaurus.com/store/your-store")
                            .font(.caption.monospaced())
                            .padding(8)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        Text("**Domain forwarding** tells browsers to redirect visitors from your custom domain (e.g. www.myshop.com) to that Prosaurus URL automatically. The redirect happens in milliseconds — visitors type your domain and land on your store.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.blue)
                            Text("**What visitors see:** After the redirect, the browser address bar will show the Prosaurus URL. This is how simple domain forwarding works.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                // Step by step
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Step-by-step setup")
                            .font(.headline)

                        Text("These instructions apply to most domain registrars (GoDaddy, Namecheap, Squarespace Domains, etc.).")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 16) {
                            stepView(number: 1, title: "Find your Prosaurus store URL", description: "Go to your Storefront settings and copy your store URL — it looks like https://www.prosaurus.com/store/your-store")

                            stepView(number: 2, title: "Log into your domain registrar", description: "Sign in to wherever you purchased your domain (GoDaddy, Namecheap, etc.).")

                            stepView(number: 3, title: "Find the forwarding settings", description: "Look for a section called Domain Forwarding, URL Forwarding, URL Redirect, or Web Forwarding. It's usually under the domain's DNS or settings panel.")

                            stepView(number: 4, title: "Create a forward rule", description: "Set From: your domain, To: your Prosaurus store URL, Type: 301 Permanent Redirect. Set up rules for both www and non-www versions if possible.")

                            stepView(number: 5, title: "Wait for DNS propagation", description: "Changes can take a few minutes to up to 24 hours to take effect worldwide.")

                            stepView(number: 6, title: "Test it", description: "Open a browser and type your custom domain. You should be redirected to your Prosaurus store.")

                            stepView(number: 7, title: "Save it in your storefront settings", description: "Once it's working, go back to your Storefront settings and enter your custom domain in the Custom Domain field.")
                        }
                    }
                }

                // Registrar guides
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Forwarding guides by registrar")
                            .font(.headline)

                        Text("Find the relevant help article for your domain provider:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 8) {
                            registrarGuide(name: "GoDaddy", hint: "Search \"forward domain GoDaddy\" in their help center")
                            registrarGuide(name: "Namecheap", hint: "Dashboard → Domain List → Manage → Redirect Domain")
                            registrarGuide(name: "Squarespace Domains", hint: "Domains panel → DNS Settings → URL Redirects")
                            registrarGuide(name: "Google Domains / Squarespace", hint: "Website tab → Forwarding")
                            registrarGuide(name: "Cloudflare", hint: "DNS → Rules → Redirect Rules")
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Domain Setup")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stepView(number: Int, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func registrarGuide(name: String, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.subheadline.weight(.medium))
            Text(hint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        CustomDomainSetupView()
    }
}
