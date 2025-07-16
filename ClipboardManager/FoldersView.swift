import SwiftUI
import CoreData

struct FoldersView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Folder.createdAt, ascending: true)],
        animation: .default)
    private var folders: FetchedResults<Folder>

    @State private var newFolderName = ""

    var body: some View {
        VStack {
            HStack {
                TextField("New Folder Name", text: $newFolderName)
                Button(action: addFolder) {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(newFolderName.isEmpty)
            }
            .padding()

            List {
                ForEach(folders) { folder in
                    Text(folder.name ?? "Untitled")
                }
                .onDelete(perform: deleteFolders)
            }
        }
        .navigationTitle("Folders")
    }

    private func addFolder() {
        withAnimation {
            let newFolder = Folder(context: viewContext)
            newFolder.id = UUID()
            newFolder.createdAt = Date()
            newFolder.name = newFolderName

            do {
                try viewContext.save()
                newFolderName = ""
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func deleteFolders(offsets: IndexSet) {
        withAnimation {
            offsets.map { folders[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct FoldersView_Previews: PreviewProvider {
    static var previews: some View {
        FoldersView().environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
