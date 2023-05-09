//
// GeneratePasswordCoordinator.swift
// Proton Pass - Created on 09/05/2023.
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

import Core
import SwiftUI
import UIKit

enum GeneratePasswordViewMode {
    /// View is shown as part of create login process
    case createLogin
    /// View is shown indepently without any context
    case random
}

enum PasswordType: CaseIterable {
    case random, memorable
}

enum WordSeparator: CaseIterable {
    case hyphens, spaces, periods, commas, underscores, numbers, symbols
}

protocol GeneratePasswordCoordinatorDelegate: AnyObject {
    func generatePasswordCoordinatorWantsToPresent(viewController: UIViewController)
}

final class GeneratePasswordCoordinator: DeinitPrintable {
    deinit { print(deinitMessage) }

    private weak var generatePasswordViewModelDelegate: GeneratePasswordViewModelDelegate?
    private let mode: GeneratePasswordViewMode
    private let wordProvider: WordProviderProtocol
    weak var delegate: GeneratePasswordCoordinatorDelegate?

    private var generatePasswordViewModel: GeneratePasswordViewModel?
    private var sheetPresentationController: UISheetPresentationController?

    init(generatePasswordViewModelDelegate: GeneratePasswordViewModelDelegate?,
         mode: GeneratePasswordViewMode,
         wordProvider: WordProviderProtocol) {
        self.generatePasswordViewModelDelegate = generatePasswordViewModelDelegate
        self.mode = mode
        self.wordProvider = wordProvider
    }

    func start() {
        guard let delegate else {
            assertionFailure("GeneratePasswordCoordinatorDelegate is not set")
            return
        }

        let viewModel = GeneratePasswordViewModel(mode: mode, wordProvider: wordProvider)
        viewModel.delegate = generatePasswordViewModelDelegate
        viewModel.uiDelegate = self
        let view = GeneratePasswordView(viewModel: viewModel)
        let viewController = UIHostingController(rootView: view)
        viewController.sheetPresentationController?.prefersGrabberVisible = true

        generatePasswordViewModel = viewModel
        sheetPresentationController = viewController.sheetPresentationController
        updateSheetHeight(passwordType: viewModel.type,
                          isShowingAdvancedOptions: viewModel.isShowingAdvancedOptions)

        delegate.generatePasswordCoordinatorWantsToPresent(viewController: viewController)
    }
}

// MARK: - Private APIs
extension GeneratePasswordCoordinator {
    func updateSheetHeight(passwordType: PasswordType, isShowingAdvancedOptions: Bool) {
        guard let sheetPresentationController else {
            assertionFailure("sheetPresentationController is null. Coordinator is not yet started.")
            return
        }

        let detent: UISheetPresentationController.Detent
        let detentIdentifier: UISheetPresentationController.Detent.Identifier

        if #available(iOS 16, *) {
            let makeCustomDetent: (Int) -> UISheetPresentationController.Detent = { height in
                UISheetPresentationController.Detent.custom { _ in
                    CGFloat(height)
                }
            }
            detent = makeCustomDetent(isShowingAdvancedOptions ? 500 : 370)
            detentIdentifier = detent.identifier
        } else {
            if isShowingAdvancedOptions {
                detent = .large()
                detentIdentifier = .large
            } else {
                detent = .medium()
                detentIdentifier = .medium
            }
        }

        sheetPresentationController.animateChanges {
            sheetPresentationController.detents = [detent]
            sheetPresentationController.selectedDetentIdentifier = detentIdentifier
        }
    }
}

// MARK: - GeneratePasswordViewModelUiDelegate
extension GeneratePasswordCoordinator: GeneratePasswordViewModelUiDelegate {
    func generatePasswordViewModelWantsToChangePasswordType(currentType: PasswordType) {
        assert(generatePasswordViewModel != nil, "generatePasswordViewModel is not set")

        let viewModel = PasswordTypesViewModel(selectedType: currentType)
        viewModel.delegate = generatePasswordViewModel

        let view = PasswordTypesView(viewModel: viewModel)
        let viewController = UIHostingController(rootView: view)

        if #available(iOS 16.0, *) {
            let customDetent = UISheetPresentationController.Detent.custom { _ in
                CGFloat(160)
            }
            viewController.sheetPresentationController?.detents = [customDetent]
        } else {
            viewController.sheetPresentationController?.detents = [.medium()]
        }

        viewController.sheetPresentationController?.prefersGrabberVisible = true

        delegate?.generatePasswordCoordinatorWantsToPresent(viewController: viewController)
    }

    func generatePasswordViewModelWantsToChangeWordSeparator(currentSeparator: WordSeparator) {
        assert(generatePasswordViewModel != nil, "generatePasswordViewModel is not set")

        let viewModel = WordSeparatorsViewModel(selectedSeparator: currentSeparator)
        viewModel.delegate = generatePasswordViewModel

        let view = WordSeparatorsView(viewModel: viewModel)
        let viewController = UIHostingController(rootView: view)

        if #available(iOS 16.0, *) {
            let customDetent = UISheetPresentationController.Detent.custom { _ in
                CGFloat(44 * WordSeparator.allCases.count + 120)
            }
            viewController.sheetPresentationController?.detents = [customDetent]
        } else {
            viewController.sheetPresentationController?.detents = [.medium()]
        }

        viewController.sheetPresentationController?.prefersGrabberVisible = true

        delegate?.generatePasswordCoordinatorWantsToPresent(viewController: viewController)
    }

    func generatePasswordViewModelWantsToUpdateSheetHeight(passwordType: PasswordType,
                                                           isShowingAdvancedOptions: Bool) {
        updateSheetHeight(passwordType: passwordType, isShowingAdvancedOptions: isShowingAdvancedOptions)
    }
}

extension GeneratePasswordViewMode {
    var confirmTitle: String {
        switch self {
        case .createLogin:
            return "Confirm"
        case .random:
            return "Copy and close"
        }
    }
}

extension PasswordType {
    var title: String {
        switch self {
        case .random:
            return "Random Password"
        case .memorable:
            return "Memorable Password"
        }
    }
}

extension WordSeparator {
    var title: String {
        switch self {
        case .hyphens:
            return "Hyphens"
        case .spaces:
            return "Spaces"
        case .periods:
            return "Periods"
        case .commas:
            return "Commas"
        case .underscores:
            return "Underscores"
        case .numbers:
            return "Numbers"
        case .symbols:
            return "Symbols"
        }
    }

    var value: String {
        switch self {
        case .hyphens:
            return "-"
        case .spaces:
            return " "
        case .periods:
            return "."
        case .commas:
            return ","
        case .underscores:
            return "_"
        case .numbers:
            if let randomNumber = AllowedCharacter.digit.rawValue.randomElement() {
                return String(randomNumber)
            } else {
                return "0"
            }
        case .symbols:
            if let specialCharacter = AllowedCharacter.special.rawValue.randomElement() {
                return String(specialCharacter)
            } else {
                return "&"
            }
        }
    }
}
