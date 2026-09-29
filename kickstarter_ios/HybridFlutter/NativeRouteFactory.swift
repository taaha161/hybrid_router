import UIKit

/// Maps a native route path to the `UIViewController` that implements it.
///
/// In the real Kickstarter app these would return the app's own controllers
/// (reward/pledge, checkout). For the talk demo they are lightweight stand-ins
/// styled to read clearly as the *native* half of the journey.
struct NativeRouteFactory {
    func make(_ path: String) -> UIViewController? {
        let base = path.split(separator: "?").first.map(String.init) ?? path
        switch true {
        case base == "/reward" || base.hasPrefix("/reward/"):
            return DemoNativePageViewController(
                title: "Back this project",
                subtitle: "reward / pledge · \(path)",
                actionTitle: "View backer profile (Flutter)",
                flutterTarget: "/backer/ada"
            )
        case base == "/checkout":
            return DemoNativePageViewController(
                title: "Checkout",
                subtitle: "checkout · \(path)",
                actionTitle: nil,
                flutterTarget: nil
            )
        default:
            return nil
        }
    }
}

/// A minimal native page used in the demo. Its "go to Flutter" button drives a
/// native → Flutter navigation (`HybridNavigator.openFlutter`), exercising the
/// interleaved `flutterA → native → flutterB` path.
final class DemoNativePageViewController: UIViewController {
    private let subtitleText: String
    private let actionTitle: String?
    private let flutterTarget: String?

    /// Injected so the action button can trigger a native → Flutter push.
    var onOpenFlutter: ((String) -> Void)?

    init(title: String, subtitle: String, actionTitle: String?, flutterTarget: String?) {
        subtitleText = subtitle
        self.actionTitle = actionTitle
        self.flutterTarget = flutterTarget
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        markAsNativeScreen()

        let badge = UILabel()
        badge.text = subtitleText
        badge.textColor = .secondaryLabel
        badge.font = .systemFont(ofSize: 13)

        let stack = UIStackView(arrangedSubviews: [badge])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        if let actionTitle, let flutterTarget {
            let button = UIButton(configuration: .filled())
            button.setTitle(actionTitle, for: .normal)
            button.addAction(UIAction { [weak self] _ in
                self?.onOpenFlutter?(flutterTarget)
            }, for: .touchUpInside)
            stack.addArrangedSubview(button)
        }

        let banner = NativeScreenBanner(feature: "UIKit · \(title ?? "")")
        view.addSubview(banner)
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
        ])
    }
}

// MARK: - "This is native" markers for the demo recording

/// Native amber, matching the deck's native colour.
let nativeAmber = UIColor(red: 0.89, green: 0.66, blue: 0.36, alpha: 1)

/// Big "this is native" strip, so a screen recording shows which side of the
/// seam each screen lives on. Flutter pages carry a matching cyan strip.
final class NativeScreenBanner: UIView {
    init(feature: String) {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 40))
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor(red: 0.55, green: 0.36, blue: 0.10, alpha: 1)

        let icon = UIImageView(image: UIImage(systemName: "apple.logo"))
        icon.tintColor = .white
        let label = UILabel()
        label.text = "NATIVE SCREEN"
        label.textColor = .white
        label.font = .systemFont(ofSize: 17, weight: .black)
        let detail = UILabel()
        detail.text = feature
        detail.textColor = UIColor.white.withAlphaComponent(0.75)
        detail.font = .systemFont(ofSize: 12)

        let row = UIStackView(arrangedSubviews: [icon, label, UIView(), detail])
        row.spacing = 10
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 40),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

extension UIViewController {
    /// Amber nav bar for this screen only.
    func markAsNativeScreen() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = nativeAmber
        appearance.titleTextAttributes = [.foregroundColor: UIColor.black]
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance
    }
}
