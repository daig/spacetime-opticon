import Foundation
import UIKit

class TabController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViewControllers()
    }
    
    private func setupViewControllers() {
        // Create the view controllers
        let recordingVC = createNavigationController(
            rootViewController: RecordingViewController(),
            title: "Record",
            systemImageName: "video.fill"
        )
        
        let viewPLYVC = createNavigationController(
            rootViewController: ViewPLYViewController(),
            title: "View PLY",
            systemImageName: "point.3.filled.connected.trianglepath.dotted"
        )
        
        // Set the view controllers
        viewControllers = [recordingVC, viewPLYVC]
    }
    
    private func createNavigationController(rootViewController: UIViewController, title: String, systemImageName: String) -> UINavigationController {
        rootViewController.title = title
        let navigationController = UINavigationController(rootViewController: rootViewController)
        navigationController.tabBarItem.title = title
        navigationController.tabBarItem.image = UIImage(systemName: systemImageName)
        return navigationController
    }
}

// Placeholder class if not already defined elsewhere in the app
// Replace or remove if already implemented
class RecordingViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        let label = UILabel()
        label.text = "Recording View"
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
} 