import UIKit
import ZaloSDK

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    ZDKApplicationDelegate.sharedInstance().application(UIApplication.shared, open: url, options: [:])
  }
}
