//
//  ViewController.swift
//  Geofence
//
//  Created by Kai Jie Wong on 31/01/2021.
//  Copyright © 2021 Kai Jie Wong. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import Reachability

class ViewController: UIViewController, UIGestureRecognizerDelegate {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var radiusText: UITextField!
    @IBOutlet weak var statusLabel: UILabel!
    
    let locationManager = CLLocationManager()
    let reachability = try! Reachability()
    
    var currentCoordinate: CLLocationCoordinate2D?
    var geofenceCoordinate: CLLocationCoordinate2D?
    var geofenceRadius = 300.0
    var geofenceCircle = MKCircle()
    var connection: Reachability.Connection?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.delegate = self
        radiusText.delegate = self
        
        self.locationManager.requestAlwaysAuthorization()
        self.locationManager.requestWhenInUseAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingLocation()
        }
        
        currentCoordinate = locationManager.location!.coordinate
        let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        let region = MKCoordinateRegion(center: currentCoordinate!, span: span)
        mapView.setRegion(region, animated: true)
        
        let gestureRecognizer = UITapGestureRecognizer(target: self, action:#selector(handleTap))
        gestureRecognizer.delegate = self
        mapView.addGestureRecognizer(gestureRecognizer)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(note:)), name: .reachabilityChanged, object: reachability)
        do {
          try reachability.startNotifier()
        }
        catch {
          print("could not start reachability notifier")
        }
    }
    
    @objc func reachabilityChanged(note: Notification) {
      let reachability = note.object as! Reachability

      switch reachability.connection {
      case .wifi:
        self.connection = .wifi
      case .cellular:
        self.connection = .cellular
      default:
        self.connection = .unavailable
      }
    }

    @objc func handleTap(gestureRecognizer: UITapGestureRecognizer) {
        let location = gestureRecognizer.location(in: mapView)
        self.geofenceCoordinate = mapView.convert(location, toCoordinateFrom: mapView)
        updateGeofence()
    }
    
    func updateGeofence() {
        radiusText.resignFirstResponder()
        
        mapView.removeOverlay(geofenceCircle)
        geofenceCircle = MKCircle(center: geofenceCoordinate!, radius: geofenceRadius)
        mapView.addOverlay(geofenceCircle)
        
        checkGeofenceStatus(userLocChanged: false)
    }
    
    func checkGeofenceStatus(userLocChanged: Bool) {
        guard geofenceCoordinate != nil else {
            return
        }
        
        let geofenceRegion = CLCircularRegion(
            center: geofenceCoordinate!,
            radius: geofenceRadius,
            identifier: "UniqueIdentifier"
        )
        
        if geofenceRegion.contains(currentCoordinate!) {
            statusLabel.text = "Inside"
        } else {
            if userLocChanged {
                guard connection != .wifi else {
                    print("Connected to same wifi")
                    return
                }
            }
            statusLabel.text = "Outside"
        }
    }
}

//MARK: MKMapViewDelegate
extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let circleRenderer = MKCircleRenderer(overlay: overlay)
        circleRenderer.lineWidth = 1.0
        circleRenderer.fillColor = UIColor.blue
        circleRenderer.alpha = 0.2
        
        return circleRenderer
    }
}

//MARK: CLLocationManagerDelegate
extension ViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentCoordinate = locationManager.location!.coordinate
        self.mapView.showsUserLocation = true

        self.checkGeofenceStatus(userLocChanged: true)
    }
}

//MARK: UITextFieldDelegate
extension ViewController: UITextFieldDelegate {
    // Only allow numbers for textfield
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let allowedCharacters = CharacterSet.decimalDigits
        let characterSet = CharacterSet(charactersIn: string)
        return allowedCharacters.isSuperset(of: characterSet)
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField.text == "" {
            textField.text = "300"
        }
        self.geofenceRadius = Double(textField.text!)!
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.updateGeofence()
        return true
    }
}
