//
// CredentialSearchResultView.swift
// Proton Pass - Created on 06/07/2023.
// Copyright (c) 2023 Proton Technologies AG
//
// This file is part of Proton Pass.
//
// Proton Pass is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Pass is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Pass. If not, see https://www.gnu.org/licenses/.

import Client
import DesignSystem
import Entities
import Macro
import Screens
import SwiftUI

struct CredentialSearchResultView: View {
    @ObservedObject private var viewModel: CredentialSearchResultViewModel
    @Binding var selectedSortType: SortType
    let getUser: (any ItemIdentifiable) -> UserUiModel?
    let selectItem: (any TitledItemIdentifiable) -> Void

    init(results: [ItemSearchResult],
         selectedSortType: Binding<SortType>,
         getUser: @escaping (any ItemIdentifiable) -> UserUiModel?,
         selectItem: @escaping (any TitledItemIdentifiable) -> Void) {
        _selectedSortType = selectedSortType
        _viewModel = .init(wrappedValue: .init(results: results,
                                               sortType: selectedSortType.wrappedValue))
        self.getUser = getUser
        self.selectItem = selectItem
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView()

            case let .loaded(results):
                headerView
                TableView(sections: results,
                          configuration: .init(showSectionIndexTitles: selectedSortType.isAlphabetical,
                                               rowSpacing: DesignConstant.sectionPadding / 2),
                          id: results.hashValue,
                          itemView: { item in
                              GenericCredentialItemRow(item: item,
                                                       user: getUser(item),
                                                       selectItem: selectItem)
                          },
                          headerView: { _ in nil })

            case let .error(error):
                RetryableErrorView(errorMessage: error.localizedDescription,
                                   onRetry: { viewModel.filterAndSortItems() })
            }
        }
        .animation(.default, value: viewModel.state)
    }
}

private extension CredentialSearchResultView {
    var headerView: some View {
        HStack {
            Text("Results")
                .font(.callout)
                .fontWeight(.bold)
                .adaptiveForegroundStyle(PassColor.textNorm.toColor) +
                Text(verbatim: " (\(viewModel.results.count))")
                .font(.callout)
                .adaptiveForegroundStyle(PassColor.textWeak.toColor)

            Spacer()

            SortTypeButton(selectedSortType: $selectedSortType)
        }
        .padding([.bottom, .horizontal])
    }
}

private typealias SearchResultSection = TableView<ItemSearchResult, GenericCredentialItemRow, Text>.Section

@MainActor
private final class CredentialSearchResultViewModel: ObservableObject {
    @Published private(set) var state: State = .loading

    enum State: Equatable {
        case loading
        case loaded([SearchResultSection])
        case error(any Error)

        static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.loaded, .loaded), (.loading, .loading):
                true
            case let (.error(lError), .error(rError)):
                lError.localizedDescription == rError.localizedDescription
            default:
                false
            }
        }
    }

    let results: [ItemSearchResult]
    private let sortType: SortType
    private var task: Task<Void, Never>?

    init(results: [ItemSearchResult], sortType: SortType) {
        self.results = results
        self.sortType = sortType
        filterAndSortItems()
    }
}

extension CredentialSearchResultViewModel {
    func filterAndSortItems() {
        task?.cancel()
        task = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    state = .loading
                }
                let type = Int.max
                let sections: [SearchResultSection] = try {
                    switch sortType {
                    case .mostRecent:
                        let results = try results.mostRecentSortResult()
                        return results.buckets.map { bucket in
                            .init(type: type,
                                  title: bucket.type.title,
                                  items: bucket.items)
                        }

                    case .alphabeticalAsc, .alphabeticalDesc:
                        let results = try results.alphabeticalSortResult(direction: sortType.sortDirection)
                        return results.buckets.map { bucket in
                            .init(type: type,
                                  title: bucket.letter.character,
                                  items: bucket.items)
                        }

                    case .newestToOldest, .oldestToNewest:
                        let results = try results.monthYearSortResult(direction: sortType.sortDirection)
                        return results.buckets.map { bucket in
                            .init(type: type,
                                  title: bucket.monthYear.relativeString,
                                  items: bucket.items)
                        }
                    }
                }()
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    state = .loaded(sections.filter { !$0.items.isEmpty })
                }
            } catch {
                if error is CancellationError { return }
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    state = .error(error)
                }
            }
        }
    }
}
