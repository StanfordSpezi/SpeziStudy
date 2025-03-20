//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//


import SpeziScheduler
import SpeziSchedulerUI
import SpeziViews
import SwiftUI


/// View that displays an ``StudyManager/ActionCard``.
public struct ActionCardView: View {
    @Environment(\.colorScheme)
    private var colorScheme
    
    let card: StudyManager.ActionCard
    let actionHandler: @MainActor (StudyManager.ActionCard.Action) async -> Void
    
    @State private var viewState: ViewState = .idle
    
    public var body: some View {
        switch card.content {
        case .event(let event):
            content(for: event)
        case .simple(let simpleContent):
            content(for: simpleContent)
        }
    }
    
    public init(card: StudyManager.ActionCard, action: @MainActor @escaping (StudyManager.ActionCard.Action) async -> Void) {
        self.card = card
        self.actionHandler = action
    }
    
    private func content(for event: Event) -> some View {
        InstructionsTile(event, alignment: .leading) {
            DefaultTileHeader(event, alignment: .leading)
        } footer: {
            EventActionButton(event: event) {
                guard let action = event.task.studyScheduledTaskAction else {
                    print("Unable to fetch associated action.")
                    return
                }
                // https://github.com/StanfordSpezi/SpeziScheduler/issues/54
                _Concurrency.Task {
                    await actionHandler(action)
                }
            }
        } more: {
            Text("MORE")
        }
    }
    
    private func content(for content: StudyManager.ActionCard.SimpleContent) -> some View {
        AsyncButton(state: $viewState) {
            await actionHandler(card.action)
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    HStack {
                        if let symbol = content.symbol {
                            Image(symbol)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .bold()
                                .frame(width: 20, height: 20)
                                .accessibilityHidden(true)
                        }
                        Text(content.title)
                            .font(.headline.bold())
                        Spacer()
                    }
                    Text(content.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .tint({ () -> Color in
            switch colorScheme {
            case .light:
                Color.black
            case .dark:
                Color.white
            @unknown default:
                Color.black
            }
        }())
    }
}
