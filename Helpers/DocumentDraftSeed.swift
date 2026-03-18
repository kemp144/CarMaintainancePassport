import Foundation

struct DocumentDraftSeed: Identifiable {
    let id = UUID()
    let pages: [DocumentDraftPage]
    let title: String
    let category: DocumentVaultCategory

    init(
        pages: [DocumentDraftPage],
        title: String,
        category: DocumentVaultCategory
    ) {
        self.pages = pages
        self.title = title
        self.category = category
    }
}
