import SwiftUI

// MARK: - Drawer

struct BookPickerDrawer: View {
    @Environment(AppUIState.self) private var ui
    let onDismiss: () -> Void

    @State private var allBooks: [Book] = []
    @State private var showPremiumSheet = false
    @State private var showCreateSheet = false
    @State private var newBookName = ""
    @State private var newBookColorId: String = Book.defaultColorId

    var body: some View {
        ZStack(alignment: .leading) {
            // 背景タップで閉じる
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // 左サイドパネル
            VStack(spacing: 0) {
                header
                Divider()
                bookList
                Divider()
                addBookButton
            }
            .frame(width: 260)
            .background(Color(.systemBackground))
            .shadow(color: .black.opacity(0.15), radius: 12, x: 4, y: 0)
        }
        .onAppear { loadBooks() }
        .onReceive(NotificationCenter.default.publisher(for: .bookChanged)) { _ in loadBooks() }
        .sheet(isPresented: $showPremiumSheet) {
            BookPremiumSheet()
        }
        .sheet(isPresented: $showCreateSheet) {
            BookCreateSheet(
                name: $newBookName,
                colorId: $newBookColorId,
                onSave: { createBook() },
                onCancel: { showCreateSheet = false }
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "books.vertical")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(L.Book.pickerTitle)
                .font(.headline)
            Spacer()
            Button { onDismiss() } label: {
                Image(systemName: "xmark")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Book List

    private var bookList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(allBooks) { book in
                    BookRow(
                        book: book,
                        isCurrent: book.id == ui.currentBook?.id,
                        onSelect: {
                            switchBook(book)
                            onDismiss()
                        }
                    )
                    Divider().padding(.leading, 52)
                }
            }
        }
    }

    // MARK: - Add Button

    private var addBookButton: some View {
        Button {
            if PremiumGate.canAddBook(existingCount: allBooks.count) {
                newBookName = ""
                newBookColorId = Book.defaultColorId
                showCreateSheet = true
            } else {
                showPremiumSheet = true
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
                Text(L.Book.newBook)
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                Spacer()
                if !PremiumGate.canAddBook(existingCount: allBooks.count) {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func loadBooks() {
        allBooks = (try? AppContainer.shared.bookRepo.allBooks()) ?? []
    }

    private func switchBook(_ book: Book) {
        AppContainer.shared.setCurrentBook(book)
        ui.currentBook = book
    }

    private func createBook() {
        let name = newBookName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            let book = try AppContainer.shared.bookRepo.createBook(name: name, colorId: newBookColorId)
            showCreateSheet = false
            switchBook(book)
            onDismiss()
        } catch {
            Logger.error("ブック作成失敗", error: error)
        }
    }
}

// MARK: - Book Row

private struct BookRow: View {
    let book: Book
    let isCurrent: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // ブックアイコン（カバーカラー付き）
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(book.color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(book.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(book.name)
                        .font(.subheadline)
                        .foregroundStyle(isCurrent ? book.color : .primary)
                        .lineLimit(1)
                    if isCurrent {
                        Text(L.Book.currentLabel)
                            .font(.caption2)
                            .foregroundStyle(book.color)
                    }
                }

                Spacer()

                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(book.color)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isCurrent ? book.color.opacity(0.06) : Color.clear)
    }
}

// MARK: - Create Sheet

private struct BookCreateSheet: View {
    @Binding var name: String
    @Binding var colorId: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section(L.Book.namePlaceholder) {
                    TextField(L.Book.namePlaceholder, text: $name)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit { if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { onSave() } }
                }
                Section(L.Book.colorLabel) {
                    LabelColorPicker(selectedColorId: colorId) { colorId = $0 ?? Book.defaultColorId }
                }
            }
            .navigationTitle(L.Book.newBook)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L.Common.cancel, action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L.Common.save, action: onSave)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { nameFocused = true }
        }
        .presentationDetents([.height(320)])
    }
}

// MARK: - Premium Sheet

private struct BookPremiumSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "crown.fill")
                .font(.system(size: 52))
                .foregroundStyle(.orange)
            VStack(spacing: 8) {
                Text(L.Book.premiumTitle)
                    .font(.title2.bold())
                Text(L.Book.premiumDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            // TODO: IAP導線を実装する
            Button(L.Book.premiumUpgrade) {}
                .buttonStyle(.borderedProminent)
                .disabled(true)
            Spacer()
            Button(L.Common.close) { dismiss() }
                .foregroundStyle(.secondary)
        }
        .padding()
        .presentationDetents([.medium])
    }
}

// MARK: - Premium Gate

enum PremiumGate {
    static let maxBooksForFree = 1

    /// ブックを追加できるか（将来の課金チェック差し替えポイント）
    static func canAddBook(existingCount: Int) -> Bool {
        // TODO: 課金実装後にここで課金状態を確認する
        return true
    }
}
