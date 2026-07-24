// ∅ 2026 lil org

import UIKit

protocol GasPriceSliderDelegate: AnyObject {
    
    func sliderInteractionStarted(value: Double)
    func sliderInteractionEnded()
    func sliderValueChanged(value: Double)
    
}

@MainActor
private func makeSpeedLabel(_ text: String) -> UILabel {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.isOpaque = false
    label.contentMode = .left
    label.text = text
    label.font = .preferredFont(forTextStyle: .body)
    label.adjustsFontForContentSizeCategory = true
    label.isAccessibilityElement = false
    label.accessibilityElementsHidden = true
    label.setContentHuggingPriority(UILayoutPriority(251), for: .horizontal)
    label.setContentHuggingPriority(UILayoutPriority(251), for: .vertical)
    return label
}

private final class SemanticSpeedSlider: UISlider {

    private static let semanticTicks =
        GasSpeedConfiguration.semanticSliderPositions.map { Float($0) }

    override func accessibilityIncrement() {
        moveToSemanticTick(increasing: true)
    }

    override func accessibilityDecrement() {
        moveToSemanticTick(increasing: false)
    }

    private func moveToSemanticTick(increasing: Bool) {
        let nextValue: Float?
        if increasing {
            nextValue = Self.semanticTicks.first(where: { $0 > value + 0.01 })
        } else {
            nextValue = Self.semanticTicks.last(where: { $0 < value - 0.01 })
        }
        guard let nextValue else { return }
        sendActions(for: .touchDown)
        setValue(nextValue, animated: true)
        sendActions(for: .valueChanged)
        sendActions(for: .touchUpInside)
    }
}

class GasPriceSliderTableViewCell: UITableViewCell {

    private let slowSpeedLabel = makeSpeedLabel("🐢")
    private let fastSpeedLabel = makeSpeedLabel("🐇")

    private let speedDetailLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.accessibilityIdentifier = "transactionSpeedDetail"
        return label
    }()

    private weak var sliderDelegate: GasPriceSliderDelegate?

    private let slider: UISlider = {
        let slider = SemanticSpeedSlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.value = 33
        slider.isContinuous = true
        slider.accessibilityLabel = Strings.transactionSpeed
        slider.accessibilityHint = Strings.transactionSpeedHint
        slider.accessibilityIdentifier = "transactionSpeedSlider"
        return slider
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViewHierarchy()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViewHierarchy()
    }

    @IBAction func sliderInteractionStarted(_ sender: Any) {
        sliderDelegate?.sliderInteractionStarted(value: Double(slider.value))
    }

    @IBAction func sliderInteractionEnded(_ sender: Any) {
        sliderDelegate?.sliderInteractionEnded()
    }
    
    @IBAction func sliderValueChanged(_ sender: Any) {
        sliderDelegate?.sliderValueChanged(value: Double(slider.value))
    }
    
    func setup(
        value: Double?,
        isEnabled: Bool,
        detail: String,
        delegate: GasPriceSliderDelegate
    ) {
        sliderDelegate = delegate
        update(value: value, isEnabled: isEnabled, detail: detail)
    }
    
    func update(value: Double?, isEnabled: Bool, detail: String) {
        slider.isEnabled = isEnabled
        slowSpeedLabel.alpha = isEnabled ? 1 : 0.5
        fastSpeedLabel.alpha = isEnabled ? 1 : 0.5
        speedDetailLabel.alpha = isEnabled ? 1 : 0.5
        speedDetailLabel.text = detail
        slider.accessibilityValue = detail
        if let value = value {
            slider.value = Float(value)
        }
    }

    private func setupViewHierarchy() {
        contentView.isOpaque = false
        contentView.clipsToBounds = true
        contentView.isMultipleTouchEnabled = true
        contentView.contentMode = .center

        contentView.addSubview(slowSpeedLabel)
        contentView.addSubview(fastSpeedLabel)
        contentView.addSubview(slider)
        contentView.addSubview(speedDetailLabel)

        slider.addTarget(self, action: #selector(sliderInteractionStarted(_:)), for: .touchDown)
        slider.addTarget(self, action: #selector(sliderInteractionEnded(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        slider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)

        NSLayoutConstraint.activate([
            slowSpeedLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            slowSpeedLabel.centerYAnchor.constraint(equalTo: slider.centerYAnchor),

            slider.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            slider.leadingAnchor.constraint(equalTo: slowSpeedLabel.trailingAnchor, constant: 8),
            slider.heightAnchor.constraint(equalToConstant: 33),

            fastSpeedLabel.leadingAnchor.constraint(equalTo: slider.trailingAnchor, constant: 8),
            fastSpeedLabel.centerYAnchor.constraint(equalTo: slider.centerYAnchor),
            contentView.trailingAnchor.constraint(equalTo: fastSpeedLabel.trailingAnchor, constant: 20),

            speedDetailLabel.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 4),
            speedDetailLabel.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 20
            ),
            speedDetailLabel.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -20
            ),
            contentView.bottomAnchor.constraint(
                equalTo: speedDetailLabel.bottomAnchor,
                constant: 16
            )
        ])
    }
    
}
