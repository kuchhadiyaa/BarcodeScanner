//
//  VideoPreviewView.swift
//  BarcodeScanner
//
//  Created by Akshay Kuchhadiya on 05/04/18.
//  Copyright © 2018 Akshay Kuchhadiya. All rights reserved.
//

import UIKit
import AVFoundation


/// VideoPreviewView Shows Video for Scanning QRCode. Its main layer is responsible for displaying video for AVCaptureSession.
class VideoPreviewView: UIView {
	
	//MARK: - Variables & Propertis
	var session:AVCaptureSession{
		get{
			let previewLayer = layer as! AVCaptureVideoPreviewLayer
			return previewLayer.session!
		}
		set(newSession){
			let previewLayer = layer as! AVCaptureVideoPreviewLayer
			previewLayer.session = newSession
		}
	}
	
	override class var layerClass : AnyClass {
		return AVCaptureVideoPreviewLayer.classForCoder()
	}
	
}
