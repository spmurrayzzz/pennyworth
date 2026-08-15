import Foundation

enum URLPolicy {
    static let allowedSchemes: Set<String> = ["http", "https"]

    static func isBareAddress(_ normalized: String) -> Bool {
        guard !normalized.contains(" ") else { return false }
        guard !normalized.contains(":") else { return false }
        if normalized == "localhost" { return true }
        if isIPAddress(normalized) { return true }
        return normalized.contains(".") && isValidHostname(normalized)
    }

    static func isIPAddress(_ text: String) -> Bool {
        let parts = text.split(separator: ".")
        guard parts.count == 4 else { return false }
        for part in parts {
            guard let value = UInt(part), value <= 255 else { return false }
            if part.count > 1 && part.hasPrefix("0") { return false }
        }
        return true
    }

    static func isValidHostname(_ text: String) -> Bool {
        guard !text.isEmpty, text.count <= 253 else { return false }
        guard !text.contains(where: { $0.isWhitespace }) else { return false }
        guard text.contains(where: { $0.isLetter }) else { return false }
        let labels = text.split(separator: ".")
        guard !labels.isEmpty else { return false }
        for label in labels {
            guard label.count > 0, label.count <= 63, label.first != "-", label.last != "-" else { return false }
            for scalar in label.unicodeScalars {
                let valid = (scalar.value >= 0x30 && scalar.value <= 0x39)
                    || (scalar.value >= 0x41 && scalar.value <= 0x5A)
                    || (scalar.value >= 0x61 && scalar.value <= 0x7A)
                    || scalar.value == 0x2D
                guard valid else { return false }
            }
        }
        return true
    }

    static func finalURL(from text: String) -> URL? {
        let candidate = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return nil }

        var complete = candidate
        let lower = candidate.lowercased()
        if !lower.hasPrefix("http://") && !lower.hasPrefix("https://") {
            if isBareAddress(lower) {
                complete = "https://\(candidate)"
            } else {
                return nil
            }
        }

        for scalar in complete.unicodeScalars where scalar.value < 0x20 {
            return nil
        }
        guard let url = URL(string: complete) else { return nil }
        guard let scheme = url.scheme?.lowercased(), allowedSchemes.contains(scheme) else { return nil }
        guard let host = url.host, isValidFinalHost(host) else { return nil }
        guard url.user == nil, url.password == nil else { return nil }
        if let port = url.port {
            guard port > 0, port <= 65535 else { return nil }
        }
        return url
    }

    static func isBareURL(_ lower: String) -> Bool {
        isBareAddress(lower)
    }

    private static func isValidFinalHost(_ host: String) -> Bool {
        if host == "localhost" { return true }
        if isIPAddress(host) { return true }
        return isValidHostname(host)
    }
}

enum TemplateURLGenerator {
    private static let sentinel = "{query}"

    enum TemplateError: LocalizedError, Equatable {
        case mustUseHTTPS
        case multiplePlaceholders
        case placeholderInInvalidComponent
        case invalidTemplate

        var errorDescription: String? {
            switch self {
            case .mustUseHTTPS: "The URL template must use https unless an explicit http exception is confirmed."
            case .multiplePlaceholders: "The URL template may contain at most one {query} placeholder."
            case .placeholderInInvalidComponent: "The {query} placeholder must appear in the path, a query value, or a fragment."
            case .invalidTemplate: "The URL template is not a valid URL."
            }
        }
    }

    private static func placeholderCount(in template: String) -> Int {
        template.components(separatedBy: sentinel).count - 1
    }

    static func validate(template: String, allowHTTP: Bool = false) throws {
        let requestObj = template.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requestObj.isEmpty, requestObj.count <= 1024 else {
            throw TemplateError.invalidTemplate
        }
        let count = placeholderCount(in: requestObj)
        guard count <= 1 else { throw TemplateError.multiplePlaceholders }

        var probe = requestObj
        if let range = probe.range(of: sentinel) {
            probe.replaceSubrange(range, with: "_q_")
        }
        guard let components = URLComponents(string: probe) else { throw TemplateError.invalidTemplate }
        guard let scheme = components.scheme?.lowercased() else { throw TemplateError.invalidTemplate }
        if scheme == "http" {
            guard allowHTTP else { throw TemplateError.mustUseHTTPS }
        } else if scheme != "https" {
            throw TemplateError.invalidTemplate
        }
        guard let host = components.host, !host.isEmpty else { throw TemplateError.invalidTemplate }
        guard components.user == nil, components.password == nil else { throw TemplateError.invalidTemplate }
        if let port = components.port {
            guard port > 0, port <= 65535 else { throw TemplateError.invalidTemplate }
        }

        if count == 1 {
            let marker = "_q_"
            if host.contains(marker) {
                throw TemplateError.placeholderInInvalidComponent
            }
            if (components.user?.contains(marker) ?? false)
                || (components.password?.contains(marker) ?? false)
            {
                throw TemplateError.placeholderInInvalidComponent
            }
        }
    }

    static func generateURL(template: String, query: String) -> URL? {
        guard template.contains(sentinel) else {
            return URLPolicy.finalURL(from: template)
        }
        var encoded: String
        let placeholderInQuery = isPlaceholder(in: .query, template: template)
        let placeholderInPath = isPlaceholder(in: .path, template: template)
        if placeholderInQuery {
            encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        } else if placeholderInPath {
            encoded = query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? query
        } else {
            encoded = query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? query
        }
        let composed = template.replacingOccurrences(of: sentinel, with: encoded)
        return URLPolicy.finalURL(from: composed)
    }

    private enum Component {
        case query, path, other
    }

    private static func isPlaceholder(in component: Component, template: String) -> Bool {
        var probe = template
        guard let range = probe.range(of: sentinel) else { return false }
        probe.replaceSubrange(range, with: "_q_")
        guard let url = URL(string: probe) else { return false }
        switch component {
        case .query:
            return url.query?.contains("_q_") ?? false
        case .path:
            return url.path.contains("_q_")
        case .other:
            return false
        }
    }
}