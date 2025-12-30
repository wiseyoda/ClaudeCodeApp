import SwiftUI
import UniformTypeIdentifiers

// MARK: - SSH Key Import Sheet

struct SSHKeyImportSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var keyContent = ""
    @State private var passphrase = ""
    @State private var showFileImporter = false
    @State private var error: String?
    @State private var isValidating = false
    @State private var detectedKeyType: SSHKeyType?

    let onKeyImported: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Icon
                Image(systemName: "key.fill")
                    .font(.system(size: 48))
                    .foregroundColor(CLITheme.cyan(for: colorScheme))
                    .padding(.top, 24)

                Text("Import SSH Private Key")
                    .font(.headline)

                // Key content text editor
                VStack(alignment: .leading, spacing: 8) {
                    Text("Paste your private key:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextEditor(text: $keyContent)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 120, maxHeight: 200)
                        .padding(8)
                        .background(CLITheme.secondaryBackground(for: colorScheme))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .onChange(of: keyContent) { _, newValue in
                            validateKey(newValue)
                        }

                    if let keyType = detectedKeyType {
                        HStack {
                            Image(systemName: keyType.isSupported ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(keyType.isSupported ? .green : .red)
                            Text("Detected: \(keyType.description)")
                                .font(.caption)
                                .foregroundColor(keyType.isSupported ? .gray : .red)
                            if !keyType.isSupported {
                                Text("(not supported)")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // Import from file button
                Button {
                    showFileImporter = true
                } label: {
                    Label("Import from Files", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(CLITheme.secondaryBackground(for: colorScheme))
                        .cornerRadius(8)
                }
                .padding(.horizontal)

                // Passphrase (optional)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Passphrase (if encrypted):")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    SecureField("Optional", text: $passphrase)
                        .padding(12)
                        .background(CLITheme.secondaryBackground(for: colorScheme))
                        .cornerRadius(8)
                }
                .padding(.horizontal)

                // Error message
                if let error = error {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(error)
                    }
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.horizontal)
                }

                Spacer()

                // Save button
                Button {
                    saveKey()
                } label: {
                    Text("Save Key")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canSave ? CLITheme.cyan(for: colorScheme) : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!canSave)
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(CLITheme.background(for: colorScheme))
            .navigationTitle("Import SSH Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.data, .text],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
    }

    private var canSave: Bool {
        guard !keyContent.isEmpty else { return false }
        guard let keyType = detectedKeyType else { return false }
        return keyType.isSupported
    }

    private func validateKey(_ content: String) {
        guard !content.isEmpty else {
            detectedKeyType = nil
            error = nil
            return
        }

        if SSHKeyDetection.isValidKeyFormat(content) {
            do {
                detectedKeyType = try SSHKeyDetection.detectPrivateKeyType(from: content)
                error = nil
            } catch {
                detectedKeyType = .unknown
                self.error = "Could not detect key type"
            }
        } else {
            detectedKeyType = nil
            error = "Invalid key format. Key should start with '-----BEGIN'"
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Request access to the file
            guard url.startAccessingSecurityScopedResource() else {
                error = "Could not access the selected file"
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                keyContent = content
                validateKey(content)
            } catch {
                self.error = "Could not read file: \(error.localizedDescription)"
            }

        case .failure(let error):
            self.error = "File selection failed: \(error.localizedDescription)"
        }
    }

    private func saveKey() {
        guard canSave else { return }

        // Normalize the key content (fixes truncation issues from paste)
        let normalizedKey = SSHKeyDetection.normalizeSSHKey(keyContent)

        // Store key in Keychain
        if KeychainHelper.shared.storeSSHKey(normalizedKey) {
            // Store passphrase if provided
            if !passphrase.isEmpty {
                KeychainHelper.shared.storePassphrase(passphrase)
            } else {
                KeychainHelper.shared.deletePassphrase()
            }

            onKeyImported()
            dismiss()
        } else {
            error = "Failed to save key to Keychain"
        }
    }
}
