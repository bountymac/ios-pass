//
// CreateVaultViewModel.swift
// Proton Pass - Created on 15/07/2022.
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
import Combine
import Core
import ProtonCore_Login
import ProtonCore_Services
import SwiftUI

protocol CreateVaultViewModelDelegate: AnyObject {
    func createVaultViewModelBeginsLoading()
    func createVaultViewModelStopsLoading()
    func createVaultViewModelDidCreateShare(share: PartialShare)
    func createVaultViewModelDidFailWithError(error: Error)
}

final class CreateVaultViewModel: DeinitPrintable, ObservableObject {
    deinit { print(deinitMessage) }

    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    @Published private var createdShare: PartialShare?

    private let coordinator: MyVaultsCoordinator
    private var cancellables = Set<AnyCancellable>()
    weak var delegate: CreateVaultViewModelDelegate?

    init(coordinator: MyVaultsCoordinator) {
        self.coordinator = coordinator

        $isLoading
            .sink { [weak self] isLoading in
                guard let self = self else { return }
                if isLoading {
                    self.delegate?.createVaultViewModelBeginsLoading()
                } else {
                    self.delegate?.createVaultViewModelStopsLoading()
                }
            }
            .store(in: &cancellables)

        $error
            .sink { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    self.delegate?.createVaultViewModelDidFailWithError(error: error)
                }
            }
            .store(in: &cancellables)

        $createdShare
            .sink { [weak self] createdShare in
                guard let self = self else { return }
                if let createdShare = createdShare {
                    self.delegate?.createVaultViewModelDidCreateShare(share: createdShare)
                }
            }
            .store(in: &cancellables)
    }

    func createVault(name: String, note: String) {
        Task { @MainActor in
            do {
                isLoading = true
                let userData = coordinator.sessionData.userData
                let createVaultEndpoint = try CreateVaultEndpoint(credential: userData.credential,
                                                                  addressKey: userData.getAddressKey(),
                                                                  name: name,
                                                                  note: note)
                let response = try await coordinator.apiService.exec(endpoint: createVaultEndpoint)
                isLoading = false
                createdShare = response.share
            } catch {
                self.error = error
                isLoading = false
            }
        }
    }
}

extension CreateVaultViewModel {
    static var preview: CreateVaultViewModel {
        .init(coordinator: .preview)
    }
}
