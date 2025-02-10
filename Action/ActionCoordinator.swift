//
// ActionCoordinator.swift
// Proton Pass - Created on 09/02/2025.
// Copyright (c) 2025 Proton Technologies AG
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

import Combine
import DesignSystem
import Factory
import Screens
import UIKit

@MainActor
final class ActionCoordinator {
    private let credentialProvider = resolve(\SharedDataContainer.credentialProvider)
    private let setUpSentry = resolve(\SharedUseCasesContainer.setUpSentry)
    private let setCoreLoggerEnvironment = resolve(\SharedUseCasesContainer.setCoreLoggerEnvironment)
    private let router = resolve(\SharedRouterContainer.mainUIKitSwiftUIRouter)
    private let sendErrorToSentry = resolve(\SharedUseCasesContainer.sendErrorToSentry)

    @LazyInjected(\SharedServiceContainer.userManager) private var userManager
    @LazyInjected(\SharedUseCasesContainer.setUpBeforeLaunching) private var setUpBeforeLaunching

    private var lastChildViewController: UIViewController?
    private weak var rootViewController: UIViewController?
    private var context: NSExtensionContext? { rootViewController?.extensionContext }

    private var cancellables = Set<AnyCancellable>()

    init(rootViewController: UIViewController?) {
        self.rootViewController = rootViewController
        AppearanceSettings.apply()
        setUpSentry()
        setUpRouter()
        setCoreLoggerEnvironment()
    }
}

// MARK: Public APIs

extension ActionCoordinator {
    func start() async {
        do {
            try await setUpBeforeLaunching(rootContainer: .viewController(rootViewController))
            await beginFlow()
        } catch {
            alert(error: error) { [weak self] in
                guard let self else { return }
                dismissExtension()
            }
        }
    }
}

// MARK: Private APIs

private extension ActionCoordinator {
    func setUpRouter() {
        router
            .globalElementDisplay
            .receive(on: DispatchQueue.main)
            .sink { [weak self] destination in
                guard let self else { return }
                switch destination {
                case let .globalLoading(shouldShow):
                    if shouldShow {
                        showLoadingHud()
                    } else {
                        hideLoadingHud()
                    }
                default:
                    return
                }
            }
            .store(in: &cancellables)
    }

    func beginFlow() async {
        if let activeUserId = userManager.activeUserId,
           credentialProvider.isAuthenticated(userId: activeUserId) {
            showView(ActionView(context: context)
                .localAuthentication(onFailure: { [weak self] _ in
                    guard let self else { return }
//                    logOut(userId: userId)
                }))
        } else {
            showNotLoggedInView()
        }
    }

    func dismissExtension() {
        context?.completeRequest(returningItems: nil)
    }

    func showNotLoggedInView() {
        let view = NotLoggedInView(variant: .actionExtension) { [weak self] in
            guard let self else { return }
            dismissExtension()
        }
        showView(view)
    }
}

// MARK: ExtensionCoordinator

extension ActionCoordinator: ExtensionCoordinator {
    func getRootViewController() -> UIViewController? {
        rootViewController
    }

    func getLastChildViewController() -> UIViewController? {
        lastChildViewController
    }

    func setLastChildViewController(_ viewController: UIViewController) {
        lastChildViewController = viewController
    }
}
