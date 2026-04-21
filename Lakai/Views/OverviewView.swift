import SwiftUI

struct OverviewView: View {
    @ObservedObject var appState: AppState

    private let columns = [
        GridItem(.adaptive(minimum: 260, maximum: 360), spacing: 18)
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [LakaiTheme.canvas, LakaiTheme.canvasAlt], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Lakai")
                                .font(.system(size: 34, weight: .black))
                            Text("Regie-Tool für Shotlists, Storyboards und Drehpläne.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(LakaiTheme.mutedInk)
                        }

                        Spacer()

                        HStack(spacing: 10) {
                            Button("Projekt importieren") {
                                appState.importProjectArchive()
                            }
                            .buttonStyle(.bordered)

                            Button("Neues Projekt") {
                                appState.createProject()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(LakaiTheme.accent)
                        }
                    }

                    LazyVGrid(columns: columns, spacing: 14) {
                        newProjectCard

                        ForEach(appState.projectSummaries) { project in
                            ZStack(alignment: .topTrailing) {
                                Button {
                                    appState.openProject(project)
                                } label: {
                                    VStack(alignment: .leading, spacing: 14) {
                                        Text(project.title)
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundStyle(LakaiTheme.ink)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        HStack(spacing: 12) {
                                            summaryPill(title: "Shots", value: String(project.shotCount))
                                            summaryPill(title: "Storyboard", value: "v\(project.storyboardVersion)")
                                            summaryPill(title: "Drehplan", value: "v\(project.scheduleVersion)")
                                        }

                                        Spacer()

                                        Text("Geändert: \(LakaiFormatters.libraryDate.string(from: project.modifiedAt))")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(LakaiTheme.mutedInk)
                                    }
                                    .padding(18)
                                    .frame(height: 180)
                                    .background(LakaiTheme.panel)
                                    .clipShape(RoundedRectangle(cornerRadius: 22))
                                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(LakaiTheme.panelBorder, lineWidth: 1))
                                }
                                .buttonStyle(.plain)

                                Button {
                                    appState.deleteProject(at: project.folderURL)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11, weight: .bold))
                                        .frame(width: 28, height: 28)
                                        .background(LakaiTheme.accentSoft)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .padding(12)
                            }
                        }
                    }
                }
                .padding(28)
            }
        }
    }

    private var newProjectCard: some View {
        Button {
            appState.createProject()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Text("Neues Projekt")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(LakaiTheme.ink)

                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(LakaiTheme.accentSoft)
                    Image(systemName: "plus")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(LakaiTheme.accent)
                }
                .frame(height: 86)

                Spacer()
            }
            .padding(18)
            .frame(height: 180)
            .background(LakaiTheme.panelElevated.opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [9, 8])).foregroundStyle(LakaiTheme.panelBorder))
        }
        .buttonStyle(.plain)
    }

    private func summaryPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(LakaiTheme.mutedInk)
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(LakaiTheme.ink)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(LakaiTheme.accentSoft.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}