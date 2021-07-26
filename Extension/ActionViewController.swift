//
//  ActionViewController.swift
//  Extension
//
//  Created by Igor Chernyshov on 23.07.2021.
//

import UIKit
import MobileCoreServices

final class ActionViewController: UIViewController {

	// MARK: - Outlets
	@IBOutlet var script: UITextView!

	// MARK: - Properties
	private var pageTitle = ""
	private var pageURL = ""

	// MARK: - Lifecycle
	override func viewDidLoad() {
		super.viewDidLoad()
		navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(loadDefaultScript))
		navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))

		NotificationCenter.default.addObserver(self,
									   selector: #selector(adjustForKeyboard),
									   name: UIResponder.keyboardWillHideNotification, object: nil)
		NotificationCenter.default.addObserver(self,
									   selector: #selector(adjustForKeyboard),
									   name: UIResponder.keyboardWillChangeFrameNotification, object: nil)

		if let inputItem = extensionContext?.inputItems.first as? NSExtensionItem {
			if let itemProvider = inputItem.attachments?.first {
				itemProvider.loadItem(forTypeIdentifier: kUTTypePropertyList as String) { [weak self] (dict, error) in
					guard let itemDictionary = dict as? NSDictionary else { return }
					guard let javaScriptValues = itemDictionary[NSExtensionJavaScriptPreprocessingResultsKey] as? NSDictionary else { return }

					self?.pageTitle = javaScriptValues["title"] as? String ?? ""
					self?.pageURL = javaScriptValues["URL"] as? String ?? ""

					DispatchQueue.main.async {
						self?.title = self?.pageTitle
						self?.loadScript()
					}
				}
			}
		}
	}

	// MARK: - Actions
	@objc private func loadDefaultScript() {
		let alertController = UIAlertController(title: "Load script", message: nil, preferredStyle: .actionSheet)
		alertController.addAction(UIAlertAction(title: "Print page title", style: .default) { [weak self] _ in
			self?.script.text = "alert(document.title);"
		})
		present(alertController, animated: UIView.areAnimationsEnabled)
	}

	@objc private func done() {
		let argument: NSDictionary = ["customJavaScript": script.text ?? ""]
		let webDictionary: NSDictionary = [NSExtensionJavaScriptFinalizeArgumentKey: argument]
		let customJavaScript = NSItemProvider(item: webDictionary, typeIdentifier: kUTTypePropertyList as String)
		let item = NSExtensionItem()
		item.attachments = [customJavaScript]
		saveScript()

		extensionContext?.completeRequest(returningItems: [item])
	}

	@objc private func adjustForKeyboard(notification: Notification) {
		guard let keyboardValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }

		let keyboardScreenEndFrame = keyboardValue.cgRectValue
		let keyboardViewEndFrame = view.convert(keyboardScreenEndFrame, from: view.window)

		if notification.name == UIResponder.keyboardWillHideNotification {
			script.contentInset = .zero
		} else {
			script.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardViewEndFrame.height - view.safeAreaInsets.bottom, right: 0)
		}

		script.scrollIndicatorInsets = script.contentInset

		let selectedRange = script.selectedRange
		script.scrollRangeToVisible(selectedRange)
	}

	// MARK: - User Defaults
	private func saveScript() {
		guard let host = URL(string: pageURL)?.host, let code = script.text else { return }
		UserDefaults.standard.setValue(code, forKey: host)
	}

	private func loadScript() {
		guard let host = URL(string: pageURL)?.host else { return }
		let code = UserDefaults.standard.string(forKey: host) ?? ""
		script.text = code
	}
}
