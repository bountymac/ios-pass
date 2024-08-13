//
// AuthenticateBiometrically.swift
// Proton Pass - Created on 13/07/2023.
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
import Entities
import LocalAuthentication

/// Biometrically authenticate with a given reason
public protocol AuthenticateBiometricallyUseCase: Sendable {
    func execute(policy: LAPolicy, reason: String) async throws -> Bool
}

public extension AuthenticateBiometricallyUseCase {
    func callAsFunction(policy: LAPolicy, reason: String) async throws -> Bool {
        try await execute(policy: policy, reason: reason)
    }
}

/**
 Do not create a class level `LAContext` or inject from the outside
 but create a new instance everytime we need to biometrically authenticate.
 Because once an instance of `LAContext` finishes evaluating, calling `evaluatePolicy`
 multiple times on a same `LAContext` always succeed without repeating authentication
 (maybe the result is cached but found no info in the docs)
 */
public final class AuthenticateBiometrically: AuthenticateBiometricallyUseCase {
    private let keychainService: any KeychainProtocol
    private let biometricKey = "BiometricsPolicyState"

    public init(keychainService: any KeychainProtocol) {
        self.keychainService = keychainService
    }

    public func execute(policy: LAPolicy, reason: String) async throws -> Bool {
        let context = LAContext()
        do {
            if policy == .deviceOwnerAuthenticationWithBiometrics {
                try biometricsChanged(context: context)
            }

            let result = try await context.evaluatePolicy(policy, localizedReason: reason)

            return result
        } catch {
            throw error
        }
    }

    func biometricsChanged(context: LAContext) throws {
        // If there is no saved policy state yet, save it
        var error: NSError?
        context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)

        if error == nil, try getBiometricsPolicyState() == nil,
           let domainState = context.evaluatedPolicyDomainState {
            try savedBiometricsPolicyState(newBiometricData: domainState)
            return
        }

        if let domainState = context.evaluatedPolicyDomainState,
           let savedDomainState = try? getBiometricsPolicyState(),
           domainState != savedDomainState {
            try? keychainService.removeOrError(forKey: biometricKey)
            throw PassError.biometricChange
        }
    }

    func savedBiometricsPolicyState(newBiometricData: Data) throws {
        try keychainService.setOrError(newBiometricData, forKey: biometricKey)
    }

    func getBiometricsPolicyState() throws -> Data? {
        try keychainService.dataOrError(forKey: biometricKey)
    }
}
