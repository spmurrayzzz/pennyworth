import AppKit

@MainActor
final class ResultRowView: NSTableCellView {
    let iconView = NSImageView()
    let titleLabel = NSTextField(labelWithString: "")
    let subtitleLabel = NSTextField(labelWithString: "")
    let positionLabel = NSTextField(labelWithString: "")

    private var pendingSource: IconSource?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) {
        fatalError("not implemented")
    }

    private func build() {
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        positionLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        positionLabel.textColor = .tertiaryLabelColor
        positionLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(positionLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: positionLabel.leadingAnchor, constant: -8),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),

            positionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            positionLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    func configure(with result: SearchResult, position: Int?) {
        titleLabel.stringValue = result.title
        subtitleLabel.stringValue = result.subtitle
        if let position {
            positionLabel.stringValue = "\u{2318}\(position)"
        } else {
            positionLabel.stringValue = ""
        }
        iconView.image = IconRepository.shared.icon(for: result.icon, size: 32)
    }

    func configure(for title: String, subtitle: String) {
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle
        positionLabel.stringValue = ""
        iconView.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
    }

    func configureOpenApp(title: String, url: URL) {
        titleLabel.stringValue = title
        subtitleLabel.stringValue = url.path
        positionLabel.stringValue = ""
        iconView.image = IconRepository.shared.icon(for: .application(url), size: 32)
    }
}