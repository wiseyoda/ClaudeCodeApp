import SwiftUI

struct TerminalView: View {
    @EnvironmentObject var settings: AppSettings
    @StateObject private var sshManager = SSHManager()
    @State private var inputText = ""
    @State private var showConnectionSheet = false
    @State private var tempPassword = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Show saved hosts if not connected
            if !sshManager.isConnected && !sshManager.isConnecting && !sshManager.availableHosts.isEmpty {
                SSHHostsBar(sshManager: sshManager)
            }

            // Terminal output
            ScrollViewReader { proxy in
                ScrollView {
                    Text(sshManager.output.isEmpty ? "Tap a saved host above or 'Connect' to start" : sshManager.output)
                        .font(settings.scaledFont(.body))
                        .foregroundColor(sshManager.output.isEmpty ? CLITheme.mutedText : CLITheme.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .textSelection(.enabled)
                        .id("output")
                }
                .background(CLITheme.background)
                .onChange(of: sshManager.output) { _, _ in
                    withAnimation {
                        proxy.scrollTo("output", anchor: .bottom)
                    }
                }
            }

            // Status bar
            TerminalStatusBar(sshManager: sshManager)

            // Special keys bar
            if sshManager.isConnected {
                SpecialKeysBar(sshManager: sshManager)
            }

            // Input area
            TerminalInputView(
                text: $inputText,
                isConnected: sshManager.isConnected,
                isFocused: _isInputFocused,
                onSend: sendCommand
            )
        }
        .background(CLITheme.background)
        .navigationTitle("Terminal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CLITheme.secondaryBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if sshManager.isConnected {
                    Button {
                        sshManager.disconnect()
                    } label: {
                        Text("Disconnect")
                            .font(settings.scaledFont(.small))
                            .foregroundColor(CLITheme.red)
                    }
                } else {
                    Button {
                        showConnectionSheet = true
                    } label: {
                        Text("Connect")
                            .font(settings.scaledFont(.small))
                            .foregroundColor(CLITheme.green)
                    }
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                if sshManager.isConnected {
                    Button {
                        sshManager.clearOutput()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(CLITheme.secondaryText)
                    }
                }
            }
        }
        .sheet(isPresented: $showConnectionSheet) {
            SSHConnectionSheet(
                sshManager: sshManager,
                tempPassword: $tempPassword,
                onConnect: { host, port, username, password in
                    Task {
                        await connect(host: host, port: port, username: username, password: password)
                    }
                },
                onConnectWithKey: { hostAlias in
                    Task {
                        await connectWithConfigHost(hostAlias)
                    }
                }
            )
        }
    }

    private func connect(host: String, port: Int, username: String, password: String) async {
        do {
            try await sshManager.connect(
                host: host,
                port: port,
                username: username,
                password: password
            )
            showConnectionSheet = false
        } catch {
            // Error is shown in the output
        }
    }

    private func connectWithConfigHost(_ hostAlias: String) async {
        do {
            try await sshManager.connectWithConfigHost(hostAlias)
            showConnectionSheet = false
        } catch {
            // Error is shown in the output
        }
    }

    private func sendCommand() {
        guard !inputText.isEmpty else { return }
        sshManager.send(inputText)
        inputText = ""
    }
}

// MARK: - SSH Hosts Bar (quick connect)

struct SSHHostsBar: View {
    @ObservedObject var sshManager: SSHManager
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("SSH:")
                    .font(settings.scaledFont(.small))
                    .foregroundColor(CLITheme.mutedText)

                ForEach(sshManager.availableHosts, id: \.host) { entry in
                    Button {
                        Task {
                            try? await sshManager.connectWithConfigHost(entry.host)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 10))
                            Text(entry.host)
                                .font(settings.scaledFont(.small))
                        }
                        .foregroundColor(CLITheme.cyan)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(CLITheme.secondaryBackground)
                        .cornerRadius(4)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(CLITheme.background)
    }
}

// MARK: - Terminal Status Bar

struct TerminalStatusBar: View {
    @ObservedObject var sshManager: SSHManager
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        HStack(spacing: 12) {
            if sshManager.isConnecting {
                HStack(spacing: 4) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: CLITheme.yellow))
                        .scaleEffect(0.7)
                    Text("connecting...")
                        .foregroundColor(CLITheme.yellow)
                }
            } else if sshManager.isConnected {
                HStack(spacing: 4) {
                    Circle()
                        .fill(CLITheme.green)
                        .frame(width: 6, height: 6)
                    Text("\(sshManager.username)@\(sshManager.host)")
                        .foregroundColor(CLITheme.green)
                }
            } else {
                HStack(spacing: 4) {
                    Circle()
                        .fill(CLITheme.red)
                        .frame(width: 6, height: 6)
                    Text("disconnected")
                        .foregroundColor(CLITheme.red)
                }
            }

            Spacer()

            if let error = sshManager.lastError {
                Text(error)
                    .foregroundColor(CLITheme.red)
                    .lineLimit(1)
            }
        }
        .font(settings.scaledFont(.small))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(CLITheme.secondaryBackground)
    }
}

// MARK: - Special Keys Bar

struct SpecialKeysBar: View {
    @ObservedObject var sshManager: SSHManager
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                SpecialKeyButton(label: "Ctrl+C", key: .ctrlC, sshManager: sshManager)
                SpecialKeyButton(label: "Ctrl+D", key: .ctrlD, sshManager: sshManager)
                SpecialKeyButton(label: "Ctrl+Z", key: .ctrlZ, sshManager: sshManager)
                SpecialKeyButton(label: "Ctrl+L", key: .ctrlL, sshManager: sshManager)
                SpecialKeyButton(label: "Tab", key: .tab, sshManager: sshManager)
                SpecialKeyButton(label: "Esc", key: .escape, sshManager: sshManager)
                SpecialKeyButton(label: "↑", key: .up, sshManager: sshManager)
                SpecialKeyButton(label: "↓", key: .down, sshManager: sshManager)
                SpecialKeyButton(label: "←", key: .left, sshManager: sshManager)
                SpecialKeyButton(label: "→", key: .right, sshManager: sshManager)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(CLITheme.secondaryBackground.opacity(0.5))
    }
}

struct SpecialKeyButton: View {
    let label: String
    let key: SpecialKey
    @ObservedObject var sshManager: SSHManager
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Button {
            sshManager.sendSpecialKey(key)
        } label: {
            Text(label)
                .font(settings.scaledFont(.small))
                .foregroundColor(CLITheme.cyan)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(CLITheme.secondaryBackground)
                .cornerRadius(4)
        }
    }
}

// MARK: - Terminal Input View

struct TerminalInputView: View {
    @Binding var text: String
    let isConnected: Bool
    @FocusState var isFocused: Bool
    let onSend: () -> Void
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        HStack(spacing: 8) {
            Text("$")
                .foregroundColor(isConnected ? CLITheme.green : CLITheme.mutedText)
                .font(settings.scaledFont(.body))

            TextField("", text: $text)
                .font(settings.scaledFont(.body))
                .foregroundColor(CLITheme.primaryText)
                .focused($isFocused)
                .disabled(!isConnected)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit { onSend() }
                .placeholder(when: text.isEmpty) {
                    Text(isConnected ? "Enter command..." : "Connect to start")
                        .foregroundColor(CLITheme.mutedText)
                        .font(settings.scaledFont(.body))
                }

            if !text.isEmpty && isConnected {
                Button(action: onSend) {
                    Image(systemName: "return")
                        .foregroundColor(CLITheme.green)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(CLITheme.background)
    }
}

// MARK: - SSH Connection Sheet

struct SSHConnectionSheet: View {
    @ObservedObject var sshManager: SSHManager
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss
    @Binding var tempPassword: String

    let onConnect: (String, Int, String, String) -> Void
    let onConnectWithKey: (String) -> Void

    @State private var host: String = ""
    @State private var port: String = "22"
    @State private var username: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // SSH Config Hosts (key-based auth)
                    if !sshManager.availableHosts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SSH Config Hosts")
                                .font(settings.scaledFont(.small))
                                .foregroundColor(CLITheme.cyan)

                            Text("Connect using ~/.ssh/config")
                                .font(settings.scaledFont(.small))
                                .foregroundColor(CLITheme.mutedText)

                            ForEach(sshManager.availableHosts, id: \.host) { entry in
                                Button {
                                    onConnectWithKey(entry.host)
                                    dismiss()
                                } label: {
                                    HStack {
                                        Image(systemName: "key.fill")
                                            .foregroundColor(CLITheme.cyan)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(entry.host)
                                                .font(settings.scaledFont(.body))
                                                .foregroundColor(CLITheme.primaryText)
                                            if let hostName = entry.hostName {
                                                Text(hostName)
                                                    .font(settings.scaledFont(.small))
                                                    .foregroundColor(CLITheme.mutedText)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(CLITheme.mutedText)
                                    }
                                    .padding(12)
                                    .background(CLITheme.secondaryBackground)
                                    .cornerRadius(8)
                                }
                            }
                        }

                        Divider()
                            .background(CLITheme.mutedText)
                            .padding(.vertical, 8)

                        Text("Or connect with password:")
                            .font(settings.scaledFont(.small))
                            .foregroundColor(CLITheme.secondaryText)
                    }

                    // Host
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Host")
                            .font(settings.scaledFont(.small))
                            .foregroundColor(CLITheme.secondaryText)
                        TextField("", text: $host)
                            .font(settings.scaledFont(.body))
                            .foregroundColor(CLITheme.primaryText)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(CLITheme.secondaryBackground)
                            .cornerRadius(8)
                    }

                    // Port
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Port")
                            .font(settings.scaledFont(.small))
                            .foregroundColor(CLITheme.secondaryText)
                        TextField("", text: $port)
                            .font(settings.scaledFont(.body))
                            .foregroundColor(CLITheme.primaryText)
                            .keyboardType(.numberPad)
                            .padding(12)
                            .background(CLITheme.secondaryBackground)
                            .cornerRadius(8)
                    }

                    // Username
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(settings.scaledFont(.small))
                            .foregroundColor(CLITheme.secondaryText)
                        TextField("", text: $username)
                            .font(settings.scaledFont(.body))
                            .foregroundColor(CLITheme.primaryText)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(CLITheme.secondaryBackground)
                            .cornerRadius(8)
                    }

                    // Password
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(settings.scaledFont(.small))
                            .foregroundColor(CLITheme.secondaryText)
                        SecureField("", text: $tempPassword)
                            .font(settings.scaledFont(.body))
                            .foregroundColor(CLITheme.primaryText)
                            .padding(12)
                            .background(CLITheme.secondaryBackground)
                            .cornerRadius(8)
                    }

                    // Save credentials toggle
                    Toggle(isOn: .constant(true)) {
                        Text("Save credentials")
                            .font(settings.scaledFont(.body))
                            .foregroundColor(CLITheme.primaryText)
                    }
                    .tint(CLITheme.cyan)

                    // Error message
                    if let error = sshManager.lastError {
                        Text(error)
                            .font(settings.scaledFont(.small))
                            .foregroundColor(CLITheme.red)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(CLITheme.red.opacity(0.1))
                            .cornerRadius(8)
                    }

                    // Connect button
                    Button {
                        // Save settings
                        settings.sshHost = host
                        settings.sshPort = Int(port) ?? 22
                        settings.sshUsername = username
                        settings.sshPassword = tempPassword

                        onConnect(host, Int(port) ?? 22, username, tempPassword)
                    } label: {
                        HStack {
                            if sshManager.isConnecting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: CLITheme.background))
                                    .scaleEffect(0.8)
                            }
                            Text(sshManager.isConnecting ? "Connecting..." : "Connect")
                                .font(settings.scaledFont(.body))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canConnect ? CLITheme.green : CLITheme.mutedText)
                        .foregroundColor(CLITheme.background)
                        .cornerRadius(8)
                    }
                    .disabled(!canConnect || sshManager.isConnecting)

                    Spacer()
                }
                .padding()
            }
            .background(CLITheme.background)
            .navigationTitle("SSH Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CLITheme.secondaryBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(CLITheme.cyan)
                }
            }
        }
        .onAppear {
            // Pre-fill from settings
            host = settings.effectiveSSHHost
            port = String(settings.sshPort)
            username = settings.sshUsername
            tempPassword = settings.sshPassword
        }
    }

    private var canConnect: Bool {
        !host.isEmpty && !username.isEmpty && !tempPassword.isEmpty
    }
}

#Preview {
    NavigationStack {
        TerminalView()
    }
    .environmentObject(AppSettings())
}
