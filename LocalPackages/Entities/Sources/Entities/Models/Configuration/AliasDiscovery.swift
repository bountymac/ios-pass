//
// AliasDiscovery.swift
// Proton Pass - Created on 21/01/2025.
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
//

public struct AliasDiscovery: OptionSet, Sendable, Codable {
    public var rawValue: Int
    public static let advancedOptions = AliasDiscovery(rawValue: 1 << 0)
    public static let customDomains = AliasDiscovery(rawValue: 1 << 1)
    public static let mailboxes = AliasDiscovery(rawValue: 1 << 2)
    public static let contacts = AliasDiscovery(rawValue: 1 << 3)

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public mutating func flip(_ option: AliasDiscovery) {
        rawValue ^= option.rawValue
    }
}
