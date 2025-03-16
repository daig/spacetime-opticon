import Foundation
import UIKit
import SwiftUI

class ViewPLYViewController: UIViewController {
    
    // UI Elements
    private var pointCloudView: PointCloudView!
    private var loadPLYButton: UIButton!
    private var loadDracoButton: UIButton!
    private var fileNameLabel: UILabel!
    private var pointCountLabel: UILabel!
    
    // Current loaded points
    private var currentPoints: [SIMD3<Float>] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Create point cloud view
        pointCloudView = PointCloudView(frame: .zero)
        pointCloudView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pointCloudView)
        
        // Create buttons
        loadPLYButton = UIButton(type: .system)
        loadPLYButton.translatesAutoresizingMaskIntoConstraints = false
        loadPLYButton.setTitle("Load PLY File", for: .normal)
        loadPLYButton.addTarget(self, action: #selector(loadPLYButtonTapped), for: .touchUpInside)
        view.addSubview(loadPLYButton)
        
        loadDracoButton = UIButton(type: .system)
        loadDracoButton.translatesAutoresizingMaskIntoConstraints = false
        loadDracoButton.setTitle("Load Draco File", for: .normal)
        loadDracoButton.addTarget(self, action: #selector(loadDracoButtonTapped), for: .touchUpInside)
        view.addSubview(loadDracoButton)
        
        // Create labels
        fileNameLabel = UILabel()
        fileNameLabel.translatesAutoresizingMaskIntoConstraints = false
        fileNameLabel.text = "No file loaded"
        fileNameLabel.textAlignment = .center
        view.addSubview(fileNameLabel)
        
        pointCountLabel = UILabel()
        pointCountLabel.translatesAutoresizingMaskIntoConstraints = false
        pointCountLabel.text = "Points: 0"
        pointCountLabel.textAlignment = .center
        view.addSubview(pointCountLabel)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // Point cloud view takes most of the screen
            pointCloudView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            pointCloudView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            pointCloudView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            pointCloudView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.7),
            
            // File name label
            fileNameLabel.topAnchor.constraint(equalTo: pointCloudView.bottomAnchor, constant: 10),
            fileNameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            fileNameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            
            // Point count label
            pointCountLabel.topAnchor.constraint(equalTo: fileNameLabel.bottomAnchor, constant: 5),
            pointCountLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            pointCountLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            
            // Buttons at the bottom
            loadPLYButton.topAnchor.constraint(equalTo: pointCountLabel.bottomAnchor, constant: 20),
            loadPLYButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            loadPLYButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.4),
            
            loadDracoButton.topAnchor.constraint(equalTo: pointCountLabel.bottomAnchor, constant: 20),
            loadDracoButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            loadDracoButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.4),
        ])
    }
    
    @objc private func loadPLYButtonTapped() {
        // Show document picker for PLY files
        let documentPicker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        present(documentPicker, animated: true)
    }
    
    @objc private func loadDracoButtonTapped() {
        // First check if we have any Draco files in the documents directory
        let fileManager = FileManager.default
        if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                let files = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
                let dracoFiles = files.filter { $0.pathExtension == "drc" }
                
                if dracoFiles.isEmpty {
                    // No Draco files found, show alert
                    let alert = UIAlertController(
                        title: "No Draco Files",
                        message: "No Draco files found in documents directory.\nFirst save a point cloud as Draco format.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    present(alert, animated: true)
                } else {
                    // Show file picker with available Draco files
                    showDracoFilePicker(files: dracoFiles)
                }
            } catch {
                print("Error accessing documents directory: \(error)")
            }
        }
    }
    
    private func showDracoFilePicker(files: [URL]) {
        // Create alert controller with action sheet style
        let alertController = UIAlertController(
            title: "Select Draco File",
            message: "Choose a file to load",
            preferredStyle: .actionSheet
        )
        
        // Add an action for each file
        for file in files {
            let fileName = file.lastPathComponent
            let action = UIAlertAction(title: fileName, style: .default) { [weak self] _ in
                self?.loadDracoFile(url: file)
            }
            alertController.addAction(action)
        }
        
        // Add cancel action
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // Present the alert controller
        present(alertController, animated: true)
    }
    
    private func loadPLYFile(url: URL) {
        // Parse PLY file and extract points
        do {
            let plyContent = try String(contentsOf: url, encoding: .utf8)
            let points = parsePLYContent(plyContent)
            
            // Update UI
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.currentPoints = points
                self.pointCloudView.updatePointCloud(points: points)
                self.fileNameLabel.text = url.lastPathComponent
                self.pointCountLabel.text = "Points: \(points.count)"
            }
        } catch {
            print("Error loading PLY file: \(error)")
            showErrorAlert(message: "Failed to load PLY file: \(error.localizedDescription)")
        }
    }
    
    private func loadDracoFile(url: URL) {
        // Use DracoService to load the file
        if let points = DracoService.shared.loadDracoPointCloudFromFile(url: url) {
            // Update UI
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.currentPoints = points
                self.pointCloudView.updatePointCloud(points: points)
                self.fileNameLabel.text = url.lastPathComponent
                self.pointCountLabel.text = "Points: \(points.count)"
            }
        } else {
            showErrorAlert(message: "Failed to load Draco file")
        }
    }
    
    private func parsePLYContent(_ content: String) -> [SIMD3<Float>] {
        var points: [SIMD3<Float>] = []
        var dataSection = false
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            if line == "end_header" {
                dataSection = true
                continue
            }
            
            if dataSection {
                // Parse vertex data
                let components = line.components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }
                
                if components.count >= 3 {
                    if let x = Float(components[0]),
                       let y = Float(components[1]),
                       let z = Float(components[2]) {
                        points.append(SIMD3<Float>(x, y, z))
                    }
                }
            }
        }
        
        return points
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UIDocumentPickerDelegate
extension ViewPLYViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        
        // Check file extension and handle accordingly
        if url.pathExtension.lowercased() == "ply" {
            loadPLYFile(url: url)
        } else if url.pathExtension.lowercased() == "drc" {
            loadDracoFile(url: url)
        } else {
            showErrorAlert(message: "Unsupported file format")
        }
    }
}

// Simple point cloud view for rendering points
class PointCloudView: UIView {
    private var points: [SIMD3<Float>] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        layer.cornerRadius = 8
        clipsToBounds = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    func updatePointCloud(points: [SIMD3<Float>]) {
        self.points = points
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard !points.isEmpty, let context = UIGraphicsGetCurrentContext() else { return }
        
        // Clear the view
        context.setFillColor(UIColor.black.cgColor)
        context.fill(rect)
        
        // Calculate scaling factors to fit the point cloud in the view
        let pointBounds = calculatePointBounds()
        let xRange = pointBounds.maxX - pointBounds.minX
        let yRange = pointBounds.maxY - pointBounds.minY
        let zRange = pointBounds.maxZ - pointBounds.minZ
        let maxRange = max(xRange, max(yRange, zRange))
        
        // Convert maxRange to CGFloat to avoid type mismatch with rect.width/height
        let maxRangeCG = CGFloat(maxRange)
        let scaleX = rect.width / (maxRangeCG != 0 ? maxRangeCG : 1)
        let scaleY = rect.height / (maxRangeCG != 0 ? maxRangeCG : 1)
        let scale = min(scaleX, scaleY) * 0.8 // 80% of view size
        
        // Calculate center offset
        let offsetX = rect.width / 2
        let offsetY = rect.height / 2
        
        // Calculate center of point cloud
        let centerX = (pointBounds.minX + pointBounds.maxX) / 2
        let centerY = (pointBounds.minY + pointBounds.maxY) / 2
        let centerZ = (pointBounds.minZ + pointBounds.maxZ) / 2
        
        // Draw points
        context.setFillColor(UIColor.white.cgColor)
        
        for point in points {
            // Normalize coordinates around center
            // Convert Float values to CGFloat to avoid type conversion errors
            let x = CGFloat(point.x - centerX) * scale + offsetX
            let y = CGFloat(point.y - centerY) * scale + offsetY
            
            // Use Z value for color (simple depth visualization)
            let normalizedZ = max(0, min(1, (point.z - pointBounds.minZ) / zRange))
            let color = UIColor(
                red: CGFloat(1.0 - normalizedZ),
                green: CGFloat(normalizedZ),
                blue: CGFloat(normalizedZ * 0.7),
                alpha: 1.0
            )
            
            context.setFillColor(color.cgColor)
            
            // Draw a small circle for each point
            let pointSize: CGFloat = 2.0
            context.fillEllipse(in: CGRect(
                x: x - pointSize/2,
                y: y - pointSize/2,
                width: pointSize,
                height: pointSize
            ))
        }
    }
    
    private func calculatePointBounds() -> (minX: Float, minY: Float, minZ: Float, maxX: Float, maxY: Float, maxZ: Float) {
        guard !points.isEmpty else {
            return (0, 0, 0, 1, 1, 1)
        }
        
        var minX = Float.greatestFiniteMagnitude
        var minY = Float.greatestFiniteMagnitude
        var minZ = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude
        var maxY = -Float.greatestFiniteMagnitude
        var maxZ = -Float.greatestFiniteMagnitude
        
        for point in points {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            minZ = min(minZ, point.z)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
            maxZ = max(maxZ, point.z)
        }
        
        return (minX, minY, minZ, maxX, maxY, maxZ)
    }
} 