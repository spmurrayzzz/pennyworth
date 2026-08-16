import AppKit

@MainActor
final class PennyworthTableRowView: NSTableRowView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.cornerCurve = .continuous
    }

    required init?(coder: NSCoder) {
        fatalError("not implemented")
    }

    override var isSelected: Bool {
        didSet {
            layer?.backgroundColor = isSelected
                ? NSColor(srgbRed: 0.13, green: 0.58, blue: 0.60, alpha: 1).cgColor
                : NSColor.clear.cgColor
            subviews.compactMap { $0 as? ResultRowView }.forEach { $0.setSelected(isSelected) }
        }
    }

    override func didAddSubview(_ subview: NSView) {
        super.didAddSubview(subview)
        (subview as? ResultRowView)?.setSelected(isSelected)
    }
}

@MainActor
final class ResultRowView: NSTableCellView {
    let iconView = NSImageView()
    let titleLabel = NSTextField(labelWithString: "")
    let subtitleLabel = NSTextField(labelWithString: "")
    let positionLabel = NSTextField(labelWithString: "")

    private var shortcutPosition: Int?

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
        titleLabel.font = .systemFont(ofSize: 19, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        positionLabel.font = .monospacedDigitSystemFont(ofSize: 17, weight: .medium)
        positionLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(positionLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 11),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: positionLabel.leadingAnchor, constant: -10),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: -2),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: positionLabel.leadingAnchor, constant: -10),

            positionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            positionLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    func configure(with result: SearchResult, position: Int?) {
        titleLabel.stringValue = result.title
        subtitleLabel.stringValue = result.subtitle
        shortcutPosition = position
        iconView.image = IconRepository.shared.icon(for: result.icon, size: 32)
        setSelected((superview as? NSTableRowView)?.isSelected == true)
    }

    func configure(for title: String, subtitle: String) {
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle
        shortcutPosition = nil
        iconView.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
        setSelected((superview as? NSTableRowView)?.isSelected == true)
    }

    func configureOpenApp(title: String, url: URL) {
        titleLabel.stringValue = title
        subtitleLabel.stringValue = url.path
        shortcutPosition = nil
        iconView.image = IconRepository.shared.icon(for: .application(url), size: 32)
        setSelected((superview as? NSTableRowView)?.isSelected == true)
    }

    func setSelected(_ selected: Bool) {
        titleLabel.textColor = selected ? .white : NSColor.white.withAlphaComponent(0.8)
        subtitleLabel.textColor = NSColor.white.withAlphaComponent(selected ? 0.82 : 0.5)
        positionLabel.textColor = NSColor.white.withAlphaComponent(selected ? 0.95 : 0.48)
        if selected {
            positionLabel.stringValue = "\u{21A9}\u{FE0E}"
        } else if let shortcutPosition {
            positionLabel.stringValue = "\u{2318}\(shortcutPosition)"
        } else {
            positionLabel.stringValue = ""
        }
    }
}
