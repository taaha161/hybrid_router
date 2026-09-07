import UIKit

/// Maps a native route path to the `UIViewController` that implements it.
///
/// In the real Kickstarter app these would return the app's own controllers
/// (reward/pledge, checkout). For the talk demo they are lightweight stand-ins
/// styled to read clearly as the *native* half of the journey.
struct NativeRouteFactory {
    func makeViewController(path: String, args: Any?) -> UIViewController? {
        let base = path.split(separator: "?").first.map(String.init) ?? path
        switch true {
        case base == "/reward" || base.hasPrefix("/reward/"):
            return DemoNativePageViewController(
                title: "Back this project",
                subtitle: "NATIVE · reward / pledge (\(path))",
                actionTitle: "View backer profile (Flutter)",
                flutterTarget: "/backer/ada"
            )
        case base == "/checkout":
            return DemoNativePageViewController(
                title: "Checkout",
                subtitle: "NATIVE · checkout (\(path))",
                actionTitle: nil,
                flutterTarget: nil
            )
        default:
            return nil
        }
    }
}

/// A minimal native page used in the demo. Its "go to Flutter" button drives a
/// native → Flutter navigation through the same navigator, exercising the
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

        let badge = UILabel()
        badge.text = "  \(subtitleText)  "
        badge.textColor = .white
        badge.backgroundColor = .systemIndigo
        badge.font = .boldSystemFont(ofSize: 13)
        badge.layer.cornerRadius = 6
        badge.clipsToBounds = true

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

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
        ])
    }
}
