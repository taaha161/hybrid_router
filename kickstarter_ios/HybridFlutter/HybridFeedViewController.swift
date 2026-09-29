import UIKit

/// Factory for the "Hybrid" tab: a native `UINavigationController` rooted at a
/// native feed, wired so its rows open Flutter project pages. Kept native so the
/// bottom bar and the feed stay on the platform side (doc Case 4), while detail
/// pages come from Flutter (doc Case 1).
enum HybridTab {
    /// A single shared nav controller so `setViewControllers` re-emits don't
    /// create duplicates.
    static let navigationController: UINavigationController = {
        let nav = UINavigationController(rootViewController: HybridFeedViewController())
        nav.tabBarItem = UITabBarItem(
            title: "Hybrid",
            image: UIImage(systemName: "square.stack.3d.up"),
            selectedImage: UIImage(systemName: "square.stack.3d.up.fill")
        )
        return nav
    }()
}

/// Native feed (the "Discovery"-like list). Tapping a row hands off to Flutter
/// via [HybridNavigator], starting the `native → flutter → native → flutter`
/// journey the talk demonstrates.
final class HybridFeedViewController: UITableViewController {
    private var navigator: HybridNavigator?

    private let projects: [(id: String, name: String, author: String)] = [
        ("42", "A Bold New Board Game", "Ada Studio"),
        ("77", "Northern Lights — an indie film", "Grace Films"),
        ("103", "Modular Synth Kit", "Turing Audio"),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Hybrid Feed"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        markAsNativeScreen()
        let header = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 40))
        let banner = NativeScreenBanner(feature: "UIKit · feed")
        header.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(equalTo: header.topAnchor),
            banner.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: header.trailingAnchor),
        ])
        tableView.tableHeaderView = header

        if let nav = navigationController {
            let navigator = HybridNavigator(navController: nav, engine: FlutterEngineManager.shared.engine)
            navigator.registerBridge()
            self.navigator = navigator
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        projects.count
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let project = projects[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = project.name
        content.secondaryText = "by \(project.author)  ·  opens in Flutter"
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // Native opens a Flutter page: placeholder + page in GoRouter, then a
        // fresh Flutter view on top.
        navigator?.openFlutter("/project/\(projects[indexPath.row].id)")
    }
}
