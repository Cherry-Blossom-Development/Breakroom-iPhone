import SwiftUI

struct EditRoomView: View {
    @Bindable var chatViewModel: ChatViewModel
    let room: ChatRoom
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var description: String

    init(chatViewModel: ChatViewModel, room: ChatRoom) {
        self.chatViewModel = chatViewModel
        self.room = room
        _name = State(initialValue: room.name)
        _description = State(initialValue: room.description ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Room Details") {
                    TextField("Room Name", text: $name)
                    TextField("Description (optional)", text: $description)
                }
            }
            .navigationTitle("Edit Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await chatViewModel.updateRoom(
                                id: room.id,
                                name: name,
                                description: description.isEmpty ? nil : description
                            )
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
