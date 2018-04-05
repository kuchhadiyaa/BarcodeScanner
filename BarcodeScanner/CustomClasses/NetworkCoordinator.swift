//
//  NetworkCoordinator.swift
//  BarcodeScanner
//
//  Created by Akshay Kuchhadiya on 05/04/18.
//  Copyright © 2018 Akshay Kuchhadiya. All rights reserved.
//

import Foundation

/// Credentials for custom google search.
/// This credentials must be stored securely not in plain text. this work is out of scope for this project.
///
/// - APIKey: Google App api key.
/// - SearchEngineKey: Search engine key.
enum Credentials:String {
	case APIKey = "AIzaSyDwe-k09g9J6qxsygoR3n22idj4w1uLr6s"
	case SearchEngineKey = "003683878426283678331:mixk2d9shfy"
}

/// Makes network request using default session.
final class NetworkCoordinator {
	
	// MARK: - Variables  -
	
	private struct ShardCoordinator{
		static var coordinator:NetworkCoordinator?
	}
	fileprivate let configuration = URLSessionConfiguration.default
	fileprivate lazy var session = URLSession(configuration: self.configuration)
	
	// MARK: - Life cycle methods  -
	
	/// Global shared accessor. Dont create individual instances.
	class var shared:NetworkCoordinator {
		if ShardCoordinator.coordinator == nil {
			ShardCoordinator.coordinator = NetworkCoordinator()
		}
		return ShardCoordinator.coordinator!
	}
	
}

// MARK: - Network requests  -

extension NetworkCoordinator {
	
	/// search using google custom search.
	/// May need to check that query param is url encodable or not.
	///
	/// - Parameters:
	///   - query: Query for search
	///   - completionHandler: result delivered on closure
	func customGoogleSearch(for query:String,completionHandler:@escaping ((_ result:String)->Void)){
		let urlString = "https://www.googleapis.com/customsearch/v1?q=\(query)&key=\(Credentials.APIKey.rawValue)&cx=\(Credentials.SearchEngineKey.rawValue)"
		guard let url = URL(string: urlString) else {
			completionHandler("Unable to make request. Invalid data")
			return
		}
		let task = session.dataTask(with: url) { data, response, error in
			DispatchQueue.main.async {
				if let error = error {
					completionHandler(error.localizedDescription)
					return
				}
				guard let httpResponse = response as? HTTPURLResponse,
					(200...299).contains(httpResponse.statusCode) else {
						completionHandler("Server error")
						return
				}
				if let mimeType = httpResponse.mimeType, mimeType == "application/json",
					let data = data,
				let json = try? JSONSerialization.jsonObject(with: data, options: .allowFragments),let googleSearchResult = json as? [String:Any]{
					if let items = googleSearchResult["items"] as? [[String:Any]],let firstResult = items.first {
						completionHandler(firstResult["title"] as? String ?? "Empty search title.")
					}else{
						completionHandler("No search results found.")
					}
				}
			}
		}
		task.resume()
	}
}
