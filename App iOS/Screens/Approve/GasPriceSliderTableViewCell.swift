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

class GasPriceSliderTableViewCell: UITableViewCell {

    private let slowSpeedLabel = makeSpeedLabel("🐢")
    private let fastSpeedLabel = makeSpeedLabel("🐇")

    private weak var sliderDelegate: GasPriceSliderDelegate?

    private let slider: UISlider = {
        let slider = UISlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumValue = 0
        slider.maximumValue = Float(
            GasSpeedConfiguration.maximumSliderPosition
        )
        slider.value = Float(
            GasSpeedConfiguration.recommendedSliderPosition
        )
        slider.isContinuous = true
        slider.accessibilityLabel = Strings.priorityFee
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
        accessibilityDetail: String,
        delegate: GasPriceSliderDelegate
    ) {
        sliderDelegate = delegate
        update(
            value: value,
            isEnabled: isEnabled,
            accessibilityDetail: accessibilityDetail
        )
    }
    
    func update(
        value: Double?,
        isEnabled: Bool,
        accessibilityDetail: String
    ) {
        slider.isEnabled = isEnabled
        slowSpeedLabel.alpha = isEnabled ? 1 : 0.5
        fastSpeedLabel.alpha = isEnabled ? 1 : 0.5
        slider.accessibilityValue = accessibilityDetail
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

        slider.addTarget(self, action: #selector(sliderInteractionStarted(_:)), for: .touchDown)
        slider.addTarget(self, action: #selector(sliderInteractionEnded(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        slider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)

        NSLayoutConstraint.activate([
            slowSpeedLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            slowSpeedLabel.centerYAnchor.constraint(equalTo: slider.centerYAnchor),

            slider.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            slider.leadingAnchor.constraint(equalTo: slowSpeedLabel.trailingAnchor, constant: 8),
            slider.heightAnchor.constraint(equalToConstant: 33),
            contentView.bottomAnchor.constraint(
                equalTo: slider.bottomAnchor,
                constant: 16
            ),

            fastSpeedLabel.leadingAnchor.constraint(equalTo: slider.trailingAnchor, constant: 8),
            fastSpeedLabel.centerYAnchor.constraint(equalTo: slider.centerYAnchor),
            contentView.trailingAnchor.constraint(equalTo: fastSpeedLabel.trailingAnchor, constant: 20)
        ])
    }
    
}
