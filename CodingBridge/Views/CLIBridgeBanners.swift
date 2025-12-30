import SwiftUI

// MARK: - Input Queued Banner

/// Shows when user input is queued (sent while agent was busy)
struct InputQueuedBanner: View {
  let position: Int
  let onCancel: () -> Void

  @EnvironmentObject var settings: AppSettings
  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    HStack(spacing: 10) {
      // Queue icon with pulse animation
      Image(systemName: "tray.full.fill")
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(CLITheme.yellow(for: colorScheme))
        .symbolEffect(.pulse)

      VStack(alignment: .leading, spacing: 2) {
        Text("Message Queued")
          .font(settings.scaledFont(.small))
          .fontWeight(.medium)
          .foregroundColor(CLITheme.primaryText(for: colorScheme))

        Text("Will be sent when Claude finishes current task")
          .font(settings.scaledFont(.small))
          .foregroundColor(CLITheme.secondaryText(for: colorScheme))
      }

      Spacer()

      // Cancel button
      Button(action: onCancel) {
        HStack(spacing: 4) {
          Image(systemName: "xmark")
            .font(.system(size: 10, weight: .semibold))
          Text("Cancel")
            .font(settings.scaledFont(.small))
            .fontWeight(.medium)
        }
        .foregroundColor(CLITheme.red(for: colorScheme))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(CLITheme.red(for: colorScheme).opacity(0.1))
        .cornerRadius(6)
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(CLITheme.secondaryBackground(for: colorScheme))
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(CLITheme.yellow(for: colorScheme).opacity(0.4), lineWidth: 1)
        )
    )
    .padding(.horizontal, 12)
    .padding(.bottom, 4)
    .transition(.move(edge: .bottom).combined(with: .opacity))
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Input queued, position \(position)")
  }
}

// MARK: - Subagent Banner

/// Shows when a subagent (Task tool) is running
struct SubagentBanner: View {
  let subagent: CLISubagentStartContent

  @EnvironmentObject var settings: AppSettings
  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    HStack(spacing: 10) {
      // Subagent icon with animation
      Image(systemName: "cpu.fill")
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(CLITheme.purple(for: colorScheme))
        .symbolEffect(.variableColor.iterative.reversing)

      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text("Subagent Running")
            .font(settings.scaledFont(.small))
            .fontWeight(.medium)
            .foregroundColor(CLITheme.primaryText(for: colorScheme))

          // Agent type badge
          Text(subagent.displayAgentType)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(CLITheme.purple(for: colorScheme))
            .cornerRadius(4)
        }

        // Task description
        Text(subagent.description)
          .font(settings.scaledFont(.small))
          .foregroundColor(CLITheme.secondaryText(for: colorScheme))
          .lineLimit(1)
          .truncationMode(.tail)
      }

      Spacer()
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(CLITheme.secondaryBackground(for: colorScheme))
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(CLITheme.purple(for: colorScheme).opacity(0.4), lineWidth: 1)
        )
    )
    .padding(.horizontal, 12)
    .padding(.bottom, 4)
    .transition(.move(edge: .bottom).combined(with: .opacity))
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Subagent \(subagent.displayAgentType) running: \(subagent.description)")
  }
}

// MARK: - Tool Progress Banner

/// Shows progress for long-running tools
struct ToolProgressBanner: View {
  let progress: CLIProgressContent

  @EnvironmentObject var settings: AppSettings
  @Environment(\.colorScheme) var colorScheme

  private var progressPercent: Double {
    guard let p = progress.progress else { return 0 }
    return Double(p) / 100.0
  }

  private var hasProgress: Bool {
    progress.progress != nil
  }

  private var progressColor: Color {
    CLITheme.cyan(for: colorScheme)
  }

  var body: some View {
    VStack(spacing: 6) {
      HStack(spacing: 8) {
        // Tool icon
        Image(systemName: "gearshape.2.fill")
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(progressColor)
          .symbolEffect(.rotate)

        // Tool name and detail
        VStack(alignment: .leading, spacing: 1) {
          Text(progress.tool)
            .font(settings.scaledFont(.small))
            .fontWeight(.medium)
            .foregroundColor(CLITheme.primaryText(for: colorScheme))

          if let detail = progress.detail {
            Text(detail)
              .font(settings.scaledFont(.small))
              .foregroundColor(CLITheme.secondaryText(for: colorScheme))
              .lineLimit(1)
              .truncationMode(.tail)
          }
        }

        Spacer()

        // Progress percentage or elapsed time
        if let p = progress.progress {
          Text("\(p)%")
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(CLITheme.secondaryText(for: colorScheme))
        } else {
          Text("\(progress.elapsedSeconds)s")
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(CLITheme.secondaryText(for: colorScheme))
        }
      }

      // Progress bar (if percentage is known)
      if hasProgress {
        GeometryReader { geometry in
          ZStack(alignment: .leading) {
            // Background
            RoundedRectangle(cornerRadius: 2)
              .fill(CLITheme.mutedText(for: colorScheme).opacity(0.2))
              .frame(height: 4)

            // Progress
            RoundedRectangle(cornerRadius: 2)
              .fill(progressColor)
              .frame(width: geometry.size.width * progressPercent, height: 4)
              .animation(.easeInOut(duration: 0.2), value: progressPercent)
          }
        }
        .frame(height: 4)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(CLITheme.secondaryBackground(for: colorScheme))
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(progressColor.opacity(0.3), lineWidth: 1)
        )
    )
    .padding(.horizontal, 12)
    .padding(.bottom, 4)
    .transition(.move(edge: .bottom).combined(with: .opacity))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(progress.tool) progress: \(progress.progress ?? 0) percent, elapsed \(progress.elapsed) seconds")
  }
}

// MARK: - Previews

#Preview("Input Queued") {
  VStack {
    Spacer()
    InputQueuedBanner(
      position: 1,
      onCancel: { print("Cancel") }
    )
    .environmentObject(AppSettings())
  }
  .background(Color.black)
}

#Preview("Subagent Running") {
  VStack {
    Spacer()
    SubagentBanner(
      subagent: CLISubagentStartContent(
        id: "task-123",
        description: "Reviewing changes for code style and best practices",
        agentType: "code-reviewer"
      )
    )
    .environmentObject(AppSettings())
  }
  .background(Color.black)
}

#Preview("Tool Progress") {
  VStack {
    Spacer()
    ToolProgressBanner(
      progress: CLIProgressContent(
        tool: "Grep",
        elapsed: 5,
        progress: 45,
        detail: "Searching source files..."
      )
    )
    .environmentObject(AppSettings())
  }
  .background(Color.black)
}
