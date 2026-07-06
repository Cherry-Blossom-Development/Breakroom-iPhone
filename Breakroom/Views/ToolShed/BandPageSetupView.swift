import SwiftUI
import PhotosUI

private let presetBackgroundColors = [
    "#1a1a2e", "#16213e", "#0f3460", "#533483",
    "#7d1e6a", "#2d3436", "#1e272e", "#000000"
]

struct BandPageSetupView: View {
    let bandId: Int
    @State private var viewModel: BandPageSetupViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?

    init(bandId: Int) {
        self.bandId = bandId
        self._viewModel = State(initialValue: BandPageSetupViewModel(bandId: bandId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading band page...")
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Error message
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.subheadline)
                                .padding(.horizontal)
                        }

                        // Save message
                        if let message = viewModel.saveMessage {
                            Text(message)
                                .foregroundStyle(.green)
                                .font(.subheadline)
                                .padding(.horizontal)
                        }

                        PublishCard(viewModel: viewModel)
                        PageSettingsCard(viewModel: viewModel)
                        BackgroundPhotoCard(viewModel: viewModel, selectedPhoto: $selectedPhoto)

                        // Members & Instruments
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Members & Instruments")
                                .font(.headline)
                            Text("Check the instruments each member plays. Changes save automatically.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                        ForEach(viewModel.members) { member in
                            MemberInstrumentsCard(viewModel: viewModel, member: member)
                        }

                        // Featured Songs
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Featured Songs")
                                .font(.headline)
                            Text("Check songs to feature on your band page. Use arrows to reorder.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                        if viewModel.songs.isEmpty {
                            Text("No band sessions uploaded yet.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                        } else {
                            ForEach(viewModel.sortedSongs) { song in
                                SongRow(viewModel: viewModel, song: song)
                            }
                        }

                        // View Public Page button
                        if let publicUrl = viewModel.publicUrl, let url = URL(string: publicUrl) {
                            Link(destination: url) {
                                HStack {
                                    Spacer()
                                    Text("View Public Page")
                                    Image(systemName: "arrow.up.right")
                                    Spacer()
                                }
                                .padding()
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .padding(.horizontal)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle(viewModel.bandName.isEmpty ? "Band Page" : "\(viewModel.bandName) — Band Page")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
        .onChange(of: selectedPhoto) {
            guard let item = selectedPhoto else { return }
            selectedPhoto = nil
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await viewModel.uploadBackground(imageData: data)
                }
            }
        }
    }
}

// MARK: - Publish Card

private struct PublishCard: View {
    @Bindable var viewModel: BandPageSetupViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Publish Band Page")
                        .font(.headline)
                    Text(viewModel.bandUrl.isEmpty ? "Set a URL below to publish your page." : "/band/\(viewModel.bandUrl)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { viewModel.isPublished },
                    set: { viewModel.updatePublished($0) }
                ))
                .labelsHidden()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Page Settings Card

private struct PageSettingsCard: View {
    @Bindable var viewModel: BandPageSetupViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Page Settings")
                .font(.headline)

            // Band URL
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("/band/")
                        .foregroundStyle(.secondary)
                    TextField("my-band-name", text: Binding(
                        get: { viewModel.bandUrl },
                        set: { viewModel.updateBandUrl($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                }
                Text("Lowercase letters, numbers, and hyphens only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Band Story
            VStack(alignment: .leading, spacing: 4) {
                Text("Band Story")
                    .font(.subheadline)
                TextEditor(text: Binding(
                    get: { viewModel.story },
                    set: { viewModel.updateStory($0) }
                ))
                .frame(minHeight: 100)
                .padding(4)
                .background(Color(.systemBackground))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separator), lineWidth: 1))
            }

            // Background Color
            VStack(alignment: .leading, spacing: 8) {
                Text("Background Color")
                    .font(.subheadline)

                // Preset colors
                HStack(spacing: 8) {
                    ForEach(presetBackgroundColors, id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex) ?? .black)
                            .frame(width: 32, height: 32)
                            .overlay {
                                if viewModel.backgroundColor == hex {
                                    Circle().stroke(Color.white, lineWidth: 2)
                                }
                            }
                            .onTapGesture {
                                viewModel.updateBackgroundColor(hex)
                            }
                    }
                }

                HStack {
                    TextField("#1a1a2e", text: Binding(
                        get: { viewModel.backgroundColor },
                        set: { viewModel.updateBackgroundColor($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)

                    if !viewModel.backgroundColor.isEmpty {
                        Button("Reset") {
                            viewModel.updateBackgroundColor("")
                        }
                        .font(.subheadline)
                    }
                }

                Text("Shown behind your page content (and behind the background photo, if set).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Save button
            Button {
                Task { await viewModel.saveSettings() }
            } label: {
                HStack {
                    if viewModel.isSavingSettings {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(viewModel.isSavingSettings ? "Saving..." : "Save Settings")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isSavingSettings)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Background Photo Card

private struct BackgroundPhotoCard: View {
    @Bindable var viewModel: BandPageSetupViewModel
    @Binding var selectedPhoto: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Background Photo")
                .font(.headline)

            if let photoUrl = viewModel.backgroundPhotoUrl {
                AuthenticatedImage(path: photoUrl)
                    .frame(height: 160)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button(role: .destructive) {
                    Task { await viewModel.removeBackground() }
                } label: {
                    Text("Remove")
                }
                .disabled(viewModel.isUploadingBackground)
            } else {
                Text("No background photo set.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                HStack {
                    if viewModel.isUploadingBackground {
                        ProgressView()
                            .controlSize(.small)
                        Text("Uploading...")
                    } else {
                        Text(viewModel.backgroundPhotoUrl != nil ? "Replace Photo" : "Upload Photo")
                    }
                }
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isUploadingBackground)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Member Instruments Card

private struct MemberInstrumentsCard: View {
    @Bindable var viewModel: BandPageSetupViewModel
    let member: BandPageMember

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Avatar
                if let photoUrl = member.photoUrl {
                    AuthenticatedImage(path: photoUrl)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 40, height: 40)
                        .overlay {
                            Text(String(member.handle.prefix(1)).uppercased())
                                .foregroundStyle(.white)
                                .font(.headline)
                        }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(member.displayName)
                        .font(.subheadline.weight(.medium))
                    HStack(spacing: 4) {
                        Text("@\(member.handle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if member.role == "owner" {
                            Text("· owner")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                if viewModel.savingMemberIds.contains(member.id) {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            // Instrument chips
            FlowLayout(spacing: 6) {
                ForEach(viewModel.instruments) { instrument in
                    let isSelected = member.instrumentIds.contains(instrument.id)
                    Button {
                        viewModel.toggleInstrument(for: member, instrumentId: instrument.id)
                    } label: {
                        Text(instrument.name)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
                            .foregroundStyle(isSelected ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Song Row

private struct SongRow: View {
    @Bindable var viewModel: BandPageSetupViewModel
    let song: BandPageSession

    var body: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.toggleSong(song)
            } label: {
                Image(systemName: song.onPage ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundStyle(song.onPage ? Color.accentColor : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(song.name?.isEmpty == false ? song.name! : "Untitled")
                    .font(.subheadline.weight(.medium))

                let meta = [song.uploaderHandle, song.instrumentName]
                    .compactMap { $0 }
                    .joined(separator: " · ")
                if !meta.isEmpty {
                    Text(meta)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if song.onPage {
                VStack(spacing: 0) {
                    Button {
                        viewModel.moveSong(song, direction: -1)
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.caption)
                            .frame(width: 28, height: 28)
                    }
                    Button {
                        viewModel.moveSong(song, direction: 1)
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .frame(width: 28, height: 28)
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// Note: FlowLayout is defined in CreateRoomView.swift
// Note: Color.init(hex:) is defined in CollectionsView.swift
