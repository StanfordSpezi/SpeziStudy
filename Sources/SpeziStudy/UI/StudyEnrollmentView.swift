//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SpeziHealthKit
import SpeziStudyDefinition
import SpeziViews
import SwiftData
import SwiftUI


/// View that lets you pick a study (or multiple) to enroll in.
public struct StudyEnrollmentView: View {
    private enum ViewState {
        case loading
        case loaded([StudyDefinition])
        case error(any Error)
        
        var isLoading: Bool {
            switch self {
            case .loading: true
            case .loaded, .error: false
            }
        }
    }
    
    public enum Source: Sendable {
        case fetchFromServer(URL)
        case constant([StudyDefinition])
    }
    
    @Environment(\.dismiss)
    private var dismiss
    
    private let source: Source
    private let selectionHandler: @MainActor (StudyDefinition) -> Void
    @StudyManagerQuery private var SPCs: [StudyParticipationContext]
    @State private var state: ViewState = .loading
    
    public var body: some View {
        NavigationStack { // swiftlint:disable:this closure_body_length
            Group {
                switch state {
                case .loading:
                    ProgressView()
                        .progressViewStyle(.circular)
                case .loaded(let studies):
                    let studies = studies.sorted(using: KeyPathComparator(\.metadata.title))
                    // "new" as in not-yet-enrolled
                    let newStudies = studies.filter { study in !SPCs.contains { $0.study.id == study.id } }
                    let alreadyEnrolledStudies = studies.filter { study in SPCs.contains { $0.study.id == study.id } }
                    Form {
                        makeStudiesSection("Available Studies", studies: newStudies)
                        makeStudiesSection("Already Enrolled", studies: alreadyEnrolledStudies)
                    }
                case .error(let error):
                    ContentUnavailableView(
                        "Unable to fetch studies",
                        systemImage: "exclamationmark.triangle",
                        description: Text(verbatim: "\(error)")
                    )
                }
            }
            .navigationTitle("Available Studies")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    DismissButton()
                }
            }
            .task {
                await fetchStudies()
            }
            .if(!state.isLoading) {
                $0.refreshable {
                    await fetchStudies()
                }
            }
        }
    }
    
    public init(source: Source, selectionHandler: @MainActor @escaping (StudyDefinition) -> Void) {
        self.source = source
        self.selectionHandler = selectionHandler
    }
    
    @ViewBuilder
    private func studyRowView(for study: StudyDefinition) -> some View {
        HStack {
            Group {
                switch study.metadata.icon {
                case nil:
                    EmptyView()
                case .systemSymbol(let name):
                    Image(systemName: name)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(.horizontal, 8)
                        .accessibilityHidden(true)
                case .custom(let url):
                    AsyncImage(url: url)
                }
            }.frame(width: 47)
            VStack(alignment: .leading) {
                Text(study.metadata.title)
                    .font(.headline.bold())
                Text(study.metadata.shortExplanationText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func makeStudiesSection(_ title: LocalizedStringResource, studies: [StudyDefinition]) -> some View {
        if !studies.isEmpty {
            Section(String(localized: title)) {
                ForEach(studies) { study in
                    let isUnavailableBcMissingDependency: Bool = { () -> Bool in // Question instead of just disabling it, hide it entirely???
                        if let dependency = study.metadata.studyDependency {
                            // studies w/ a dependency are only allowed if the user is already in the other study
                            return !SPCs.contains(where: { $0.study.id == dependency })
                        } else {
                            // studies w/out a dependency are always allowed
                            return false
                        }
                    }()
                    Section {
                        NavigationLink {
                            StudyInfoView(study: study, dismiss: dismiss)
                        } label: {
                            studyRowView(for: study)
                            if isUnavailableBcMissingDependency {
                                Text("Unavailable: not enrolled into parent(dep) study.")
                            }
                        }.disabled(isUnavailableBcMissingDependency)
                    }
                }
            }
        }
    }
    
    private func fetchStudies() async {
        state = .loading
        do {
            switch source {
            case .constant(let studies):
                state = .loaded(studies)
            case .fetchFromServer(let url):
                let (data, _) = try await URLSession.shared.data(from: url)
                state = .loaded(try JSONDecoder().decode([StudyDefinition].self, from: data))
            }
        } catch {
            state = .error(error)
        }
    }
}
