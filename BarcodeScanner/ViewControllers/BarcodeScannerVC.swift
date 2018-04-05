//
//  BarcodeScannerVC.swift
//  BarcodeScanner
//
//  Created by Akshay Kuchhadiya on 05/04/18.
//  Copyright © 2018 Akshay Kuchhadiya. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class BarcodeScannerVC: UIViewController {

	// MARK: - Variables
	let captureMetadataOutput = AVCaptureMetadataOutput()
	var captureSession:AVCaptureSession!
	var captureDeviceBack:AVCaptureDevice?
	var captureDeviceCurretlyActive:AVCaptureDevice?
	var captureDeviceInputCurrentlyActive:AVCaptureDeviceInput?
	var videoOutput:AVCaptureVideoDataOutput?
	var visionRequests:[VNRequest] = []
	
	// MARK: - Life cycle methods  -
	
	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
		initializeComponents()
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}


}

// MARK: - Helper methods  -

extension BarcodeScannerVC {
	/// Initalize components.
	fileprivate func initializeComponents(){
		//Create barcode detection request.
		let barcodeRequest = VNDetectBarcodesRequest { [weak self](request, error) in
			if let errorMessage = error?.localizedDescription {
				self?.showAlert(with: errorMessage)
				return
			}
			if let firstResult = request.results?.first as? VNBarcodeObservation,let barcodeString = firstResult.payloadStringValue {
				NetworkCoordinator.shared.customGoogleSearch(for: barcodeString) { [weak self] (result) in
					self?.showAlert(with: result)
				}
			}else{
				self?.showAlert(with: "No machine readable code found.")
			}
		}
		visionRequests.append(barcodeRequest)

		initiateCamera()
	}
	
	/// Check camera permission.
	func initiateCamera(){
		captureSession = AVCaptureSession()
		captureSession.sessionPreset = AVCaptureSession.Preset.high
		let viewPreviewView = view as! VideoPreviewView
		viewPreviewView.session = captureSession
		let previewLayer = view.layer as! AVCaptureVideoPreviewLayer
		previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
		let authorizationStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
		
		weak var selfWeak = self
		switch authorizationStatus {
			
		case .notDetermined:
			AVCaptureDevice.requestAccess(for: AVMediaType.video,
										  completionHandler: { (granted:Bool) -> Void in
											DispatchQueue.main.async(execute: { () -> Void in
												if granted {
													
													if selfWeak?.captureDeviceCurretlyActive == nil {
														selfWeak?.configureSession()
													}
													selfWeak?.captureSession.startRunning()
												}
											})
			})
		case .authorized:
			DispatchQueue.main.async(execute: { () -> Void in
				if selfWeak?.captureDeviceCurretlyActive == nil {
					selfWeak?.configureSession()
				}
				selfWeak?.captureSession.startRunning()
			})
		case .denied, .restricted:
			DispatchQueue.main.async(execute: { () -> Void in
				
			})
		}
	}
	
	/// Initialize camera session. Configure camere to detect QRCode output.
	func configureSession(){
		
		captureSession.beginConfiguration()
		
		let devicesAvailable = AVCaptureDevice.devices(for: AVMediaType.video)
		for captureDevice in devicesAvailable{
			if captureDevice.position == .back {
				captureDeviceBack = captureDevice
			}
		}
		
		do {
			if captureDeviceBack != nil {
				captureDeviceInputCurrentlyActive = try AVCaptureDeviceInput(device: captureDeviceBack!)
				if captureSession.canAddInput(captureDeviceInputCurrentlyActive!) {
					captureSession.addInput(captureDeviceInputCurrentlyActive!)
					captureDeviceCurretlyActive = captureDeviceBack
				}
			}
		}catch{
			
		}
		// Initialize a AVCaptureMetadataOutput object and set it as the output device to the capture session.
		captureSession.addOutput(captureMetadataOutput)
		captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
		captureMetadataOutput.metadataObjectTypes = captureMetadataOutput.availableMetadataObjectTypes

		
		videoOutput = AVCaptureVideoDataOutput()
		if captureSession.canAddOutput(self.videoOutput!) {
			captureSession.addOutput(self.videoOutput!)
		}
		captureSession.commitConfiguration()
	}

	
	/// Display message using alert and on ok resume session.
	///
	/// - Parameter message: Message to display
	fileprivate func showAlert(with message:String){
		let alertController = UIAlertController.init(title: "Google Result", message: message, preferredStyle: .alert)
		let okButton = UIAlertAction(title: "Ok", style: .destructive, handler: { [weak self](action) in
			self?.captureSession.startRunning()
		})
		alertController.addAction(okButton)
		present(alertController, animated: true, completion: nil)
	}
}

// MARK: - Capture metadata output delegate

extension BarcodeScannerVC : AVCaptureMetadataOutputObjectsDelegate{
	func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
		// Check if the metadataObjects array is not nil and it contains at least one object.
		if metadataObjects.count == 0 {
			///Not detected.
			return
		}
		
		// Get the metadata object.
		if let metadataObj = metadataObjects[0] as? AVMetadataMachineReadableCodeObject,let code = metadataObj.stringValue {
			///Barcode parse
			//Stop session and get custom search api result
			captureSession.stopRunning()
			NetworkCoordinator.shared.customGoogleSearch(for: code) { [weak self] (result) in
				self?.showAlert(with: result)
			}
		}
	}
}


extension BarcodeScannerVC {
	
	@IBAction func buttonGalleryTapped(_ sender: UIButton) {
		sender.isEnabled = false
		//Show image picker.
		let imagePicker = UIImagePickerController()
		imagePicker.allowsEditing = false
		imagePicker.delegate = self
		present(imagePicker, animated: true, completion: nil)
		DispatchQueue.main.async {
			sender.isEnabled = true
		}
	}
}

extension BarcodeScannerVC: UIImagePickerControllerDelegate,UINavigationControllerDelegate {
	func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
		picker.dismiss(animated: true, completion: nil)
		if let image = info[UIImagePickerControllerOriginalImage] as? UIImage,let cgImage = image.cgImage {
			captureSession.stopRunning()
			let imageRequestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
			do{
				try imageRequestHandler.perform(visionRequests)
			}catch {
				showAlert(with: error.localizedDescription)
			}
		}
	}
	func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
		picker.dismiss(animated: true, completion: nil)
	}
}
