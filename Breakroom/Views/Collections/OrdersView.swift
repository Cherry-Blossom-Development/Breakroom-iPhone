import SwiftUI

struct OrdersView: View {
    @State private var orders: [Order] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var activeFilter: String = "all"
    @State private var expandedOrderId: Int?

    private let filters = [
        ("all", "All"),
        ("paid", "Paid"),
        ("shipped", "Shipped"),
        ("delivered", "Delivered"),
        ("cancelled", "Cancelled")
    ]

    private var filteredOrders: [Order] {
        if activeFilter == "all" {
            return orders
        }
        return orders.filter { $0.status == activeFilter }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading orders...")
            } else if let error {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        Task { await loadOrders() }
                    }
                }
            } else if orders.isEmpty {
                emptyState
            } else {
                ordersList
            }
        }
        .navigationTitle("Orders")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadOrders()
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No orders yet", systemImage: "shippingbox")
        } description: {
            Text("When someone purchases from your storefront, their order will appear here.")
        }
    }

    private var ordersList: some View {
        List {
            // Filter pills
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filters, id: \.0) { value, label in
                            FilterPill(
                                label: label,
                                count: countByStatus(value),
                                isActive: activeFilter == value
                            ) {
                                activeFilter = value
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            // Orders
            ForEach(filteredOrders) { order in
                OrderCard(
                    order: order,
                    isExpanded: expandedOrderId == order.id,
                    onToggle: {
                        withAnimation {
                            if expandedOrderId == order.id {
                                expandedOrderId = nil
                            } else {
                                expandedOrderId = order.id
                            }
                        }
                    },
                    onShipped: { updatedOrder in
                        if let index = orders.firstIndex(where: { $0.id == updatedOrder.id }) {
                            orders[index] = updatedOrder
                        }
                    }
                )
            }
        }
        .listStyle(.plain)
    }

    private func countByStatus(_ status: String) -> Int {
        if status == "all" {
            return orders.count
        }
        return orders.filter { $0.status == status }.count
    }

    private func loadOrders() async {
        isLoading = true
        error = nil
        do {
            orders = try await CollectionsAPIService.getOrders()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Filter Pill

private struct FilterPill: View {
    let label: String
    let count: Int
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                Text("\(count)")
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isActive ? Color.white.opacity(0.25) : Color(.systemGray5))
                    .clipShape(Capsule())
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isActive ? Color.accentColor : Color(.secondarySystemBackground))
            .foregroundStyle(isActive ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Order Card

private struct OrderCard: View {
    let order: Order
    let isExpanded: Bool
    let onToggle: () -> Void
    let onShipped: (Order) -> Void

    @State private var trackingCarrier = ""
    @State private var trackingNumber = ""
    @State private var isShipping = false
    @State private var shipError: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header (always visible)
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    // Thumbnail
                    if let imagePath = order.itemImage {
                        AsyncImage(url: URL(string: "\(APIClient.shared.baseURL)/api/uploads/\(imagePath)")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray.opacity(0.2)
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 50, height: 50)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            }
                    }

                    // Summary
                    VStack(alignment: .leading, spacing: 2) {
                        Text(order.itemName ?? "Unknown item")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text("\(order.buyerName ?? "Unknown") · \(order.formattedDate)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Right side
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(order.totalFormatted)
                            .font(.subheadline.weight(.bold))
                        StatusBadge(status: order.status, label: order.statusLabel)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            // Expanded details
            if isExpanded {
                Divider()
                    .padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 16) {
                    // Buyer info
                    DetailSection(title: "Buyer") {
                        Text(order.buyerName ?? "Unknown")
                        if let email = order.buyerEmail {
                            Text(email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Shipping address
                    DetailSection(title: "Ship to") {
                        Text(order.shipToName ?? "")
                        if let addr1 = order.shipToAddress1 {
                            Text(addr1)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let city = order.shipToCity, let state = order.shipToState, let zip = order.shipToZip {
                            Text("\(city), \(state) \(zip)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Payment info
                    DetailSection(title: "Payment") {
                        Text("\(order.itemPriceFormatted) item")
                        Text("\(order.shippingCostFormatted) shipping")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Total: \(order.totalFormatted)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Tracking info (if shipped)
                    if let tracking = order.trackingNumber, !tracking.isEmpty {
                        DetailSection(title: "Tracking") {
                            Text("\(order.trackingCarrier ?? "") \(tracking)")
                        }
                    }

                    // Ship form (if can ship)
                    if order.canShip {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Mark as shipped")
                                .font(.subheadline.weight(.semibold))

                            HStack(spacing: 8) {
                                Menu {
                                    Button("USPS") { trackingCarrier = "USPS" }
                                    Button("UPS") { trackingCarrier = "UPS" }
                                    Button("FedEx") { trackingCarrier = "FedEx" }
                                    Button("DHL") { trackingCarrier = "DHL" }
                                    Button("Other") { trackingCarrier = "Other" }
                                } label: {
                                    HStack {
                                        Text(trackingCarrier.isEmpty ? "Carrier" : trackingCarrier)
                                            .foregroundStyle(trackingCarrier.isEmpty ? .secondary : .primary)
                                        Image(systemName: "chevron.down")
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }

                                TextField("Tracking # (optional)", text: $trackingNumber)
                                    .textFieldStyle(.roundedBorder)
                            }

                            Button {
                                Task { await markShipped() }
                            } label: {
                                HStack {
                                    if isShipping {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                    Text(isShipping ? "Saving..." : "Mark as Shipped")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isShipping)

                            if let shipError {
                                Text(shipError)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    private func markShipped() async {
        isShipping = true
        shipError = nil

        do {
            let updatedOrder = try await CollectionsAPIService.markOrderShipped(
                orderId: order.id,
                trackingNumber: trackingNumber.isEmpty ? nil : trackingNumber,
                trackingCarrier: trackingCarrier.isEmpty ? nil : trackingCarrier
            )
            onShipped(updatedOrder)
        } catch {
            shipError = error.localizedDescription
        }

        isShipping = false
    }
}

// MARK: - Status Badge

private struct StatusBadge: View {
    let status: String
    let label: String

    private var backgroundColor: Color {
        switch status {
        case "pending_payment": return .orange.opacity(0.15)
        case "paid": return .green.opacity(0.15)
        case "processing": return .blue.opacity(0.15)
        case "shipped": return .purple.opacity(0.15)
        case "delivered": return .green.opacity(0.15)
        case "cancelled", "refunded": return .red.opacity(0.15)
        default: return .gray.opacity(0.15)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case "pending_payment": return .orange
        case "paid": return .green
        case "processing": return .blue
        case "shipped": return .purple
        case "delivered": return .green
        case "cancelled", "refunded": return .red
        default: return .gray
        }
    }

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .textCase(.uppercase)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
    }
}

// MARK: - Detail Section

private struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            content()
                .font(.subheadline)
        }
    }
}
