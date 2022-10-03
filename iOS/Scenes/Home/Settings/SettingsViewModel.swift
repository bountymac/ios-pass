//
// SettingsViewModel.swift
// Proton Pass - Created on 28/09/2022.
// Copyright (c) 2022 Proton Technologies AG
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
import Core
import SwiftUI

public enum SettingsKeys {
    public static let quickTypeBar = "quickTypeBar"
}

final class SettingsViewModel: BaseViewModel, DeinitPrintable, ObservableObject {
    private let credentialRepository: CredentialRepositoryProtocol

    // Use a temporary boolean here because enabling/disabling can throw errors
    // and when errors happen, we can rollback this boolean
    @Published var tempQuickTypeBar = true {
        didSet {
            populateOrRemoveCredentials()
        }
    }
    @AppStorage(SettingsKeys.quickTypeBar) private var quickTypeBar = true

    /// Whether user has picked Proton Pass as AutoFill provider in Settings
    @Published private(set) var autoFillEnabled = false {
        didSet {
            populateOrRemoveCredentials()
        }
    }

    var onToggleSidebar: (() -> Void)?

    init(credentialRepository: CredentialRepositoryProtocol) {
        self.credentialRepository = credentialRepository
        super.init()
        self.tempQuickTypeBar = quickTypeBar
        self.updateAutoFillAvalability()

        NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.updateAutoFillAvalability()
            }
            .store(in: &cancellables)
    }

    private func updateAutoFillAvalability() {
        Task { @MainActor in
            self.autoFillEnabled = await credentialRepository.isEnabled()
        }
    }

    private func populateOrRemoveCredentials() {
        // When not enabled, iOS already deleted the credential database.
        // Atempting to populate this database will throw an error anyway so early exit here
        guard autoFillEnabled else { return }

        guard tempQuickTypeBar != quickTypeBar else { return }
        Task { @MainActor in
            defer { isLoading = false }
            do {
                isLoading = true
                if tempQuickTypeBar {
                    try await credentialRepository.populateCredentials()
                } else {
                    try await credentialRepository.removeAllCredentials()
                }
                quickTypeBar = tempQuickTypeBar
            } catch {
                self.tempQuickTypeBar.toggle() // rollback to previous value
                self.error = error
            }
        }
    }
}

// MARK: - Actions
extension SettingsViewModel {
    func toggleSidebar() { onToggleSidebar?() }
}
