//
// GetDomainComponents.swift
// Proton Pass - Created on 02/05/2024.
// Copyright (c) 2024 Proton Technologies AG
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
//

import Entities
import Foundation
@preconcurrency import PassRustCore

public protocol GetDomainComponentsUseCase: Sendable {
    func execute(of url: URL) throws -> DomainComponents
}

public extension GetDomainComponentsUseCase {
    func callAsFunction(of url: URL) throws -> DomainComponents {
        try execute(of: url)
    }
}

public final class GetDomainComponents: GetDomainComponentsUseCase {
    private let domainManager: any DomainManagerProtocol

    public init(domainManager: any DomainManagerProtocol = DomainManager()) {
        self.domainManager = domainManager
    }

    public func execute(of url: URL) throws -> DomainComponents {
        let urlString = url.absoluteString
        let tld = try domainManager.getRootDomain(input: urlString)
        let domain = try domainManager.getDomain(input: urlString)
        return DomainComponents(tld: tld, domain: domain)
    }
}
