import SwiftUI

struct ShippingSetupView: View {
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var error: String?
    @State private var showSuccess = false

    // Form fields
    @State private var addressLine1 = ""
    @State private var addressLine2 = ""
    @State private var city = ""
    @State private var stateRegion = ""
    @State private var zip = ""
    @State private var country = "US"
    @State private var shipDestinations = "us_only"
    @State private var processingTime = "1_2_days"

    private let countries = [
        ("US", "United States"),
        ("CA", "Canada"),
        ("GB", "United Kingdom"),
        ("AU", "Australia"),
        ("DE", "Germany"),
        ("FR", "France"),
        ("NL", "Netherlands"),
        ("JP", "Japan"),
        ("OTHER", "Other")
    ]

    private let destinationOptions = [
        ("us_only", "United States only", "Domestic shipping only"),
        ("us_canada", "United States & Canada", "North American shipping"),
        ("worldwide", "Worldwide", "Ship to any country")
    ]

    private let processingOptions = [
        ("same_day", "Same day"),
        ("1_2_days", "1–2 business days"),
        ("3_5_days", "3–5 business days"),
        ("1_2_weeks", "1–2 weeks"),
        ("2_4_weeks", "2–4 weeks")
    ]

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading settings...")
            } else {
                formContent
            }
        }
        .navigationTitle("Shipping Setup")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadSettings()
        }
        .alert("Error", isPresented: .init(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK") { error = nil }
        } message: {
            if let error {
                Text(error)
            }
        }
    }

    private var formContent: some View {
        Form {
            // Ship-from address section
            Section {
                TextField("Address line 1", text: $addressLine1)
                    .textContentType(.streetAddressLine1)
                TextField("Address line 2 (optional)", text: $addressLine2)
                    .textContentType(.streetAddressLine2)
                TextField("City", text: $city)
                    .textContentType(.addressCity)
                HStack {
                    TextField("State / Region", text: $stateRegion)
                        .textContentType(.addressState)
                    TextField("ZIP / Postal", text: $zip)
                        .textContentType(.postalCode)
                        .frame(width: 100)
                }
                Picker("Country", selection: $country) {
                    ForEach(countries, id: \.0) { code, name in
                        Text(name).tag(code)
                    }
                }
            } header: {
                Text("Ship-from address")
            } footer: {
                Text("The address your packages originate from. Required for carrier rate calculation.")
            }

            // Shipping destinations section
            Section {
                ForEach(destinationOptions, id: \.0) { value, title, description in
                    Button {
                        shipDestinations = value
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title)
                                    .foregroundStyle(.primary)
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if shipDestinations == value {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            } header: {
                Text("Shipping destinations")
            } footer: {
                Text("Where are you willing to ship? Buyers outside your allowed destinations won't be able to check out.")
            }

            // Processing time section
            Section {
                Picker("Processing time", selection: $processingTime) {
                    ForEach(processingOptions, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }
            } header: {
                Text("Processing time")
            } footer: {
                Text("How long after an order is placed before you ship it. This is shown to buyers on your public store.")
            }

            // Save button section
            Section {
                Button {
                    Task { await saveSettings() }
                } label: {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text(showSuccess ? "Saved!" : "Save Settings")
                        }
                        Spacer()
                    }
                }
                .disabled(isSaving)
            }
        }
    }

    private func loadSettings() async {
        isLoading = true
        do {
            if let settings = try await CollectionsAPIService.getShippingSettings() {
                addressLine1 = settings.addressLine1 ?? ""
                addressLine2 = settings.addressLine2 ?? ""
                city = settings.city ?? ""
                stateRegion = settings.stateRegion ?? ""
                zip = settings.zip ?? ""
                country = settings.country
                shipDestinations = settings.shipDestinations
                processingTime = settings.processingTime
            }
        } catch {
            // Use defaults if no settings exist
        }
        isLoading = false
    }

    private func saveSettings() async {
        isSaving = true
        error = nil
        showSuccess = false

        let settings = ShippingSettings(
            addressLine1: addressLine1.isEmpty ? nil : addressLine1,
            addressLine2: addressLine2.isEmpty ? nil : addressLine2,
            city: city.isEmpty ? nil : city,
            stateRegion: stateRegion.isEmpty ? nil : stateRegion,
            zip: zip.isEmpty ? nil : zip,
            country: country,
            shipDestinations: shipDestinations,
            processingTime: processingTime
        )

        do {
            _ = try await CollectionsAPIService.saveShippingSettings(settings)
            showSuccess = true
            // Reset success message after delay
            Task {
                try? await Task.sleep(for: .seconds(2))
                showSuccess = false
            }
        } catch {
            self.error = error.localizedDescription
        }

        isSaving = false
    }
}
