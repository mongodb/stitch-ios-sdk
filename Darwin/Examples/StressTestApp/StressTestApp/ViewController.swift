//
//  ViewController.swift
//  StressTestApp
//
//  Created by Tyler Kaye on 3/14/19.
//  Copyright © 2019 Tyler Kaye. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var numSyncedDocsLabel: UILabel!
    
    @IBOutlet weak var numDocsToInsertInput: UITextField!
    @IBOutlet weak var docSizeInput: UITextField!
    
    @IBOutlet weak var insertManyButton: UIButton!
    @IBOutlet weak var clearAllDocsButton: UIButton!
    @IBOutlet weak var syncPassButton: UIButton!
    
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var networkLabel: UILabel!
    @IBOutlet weak var cpuLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let cornerRadius: CGFloat = 20;
        insertManyButton.layer.cornerRadius = cornerRadius;
        clearAllDocsButton.layer.cornerRadius = cornerRadius;
        syncPassButton.layer.cornerRadius = cornerRadius;
        
        // Keyboard dismissal
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:)))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)
    }

    @IBAction func insertManyClicked(_ sender: Any) {
        let numDocs = integer(from: numDocsToInsertInput)
        DispatchQueue.main.async() {
            self.timeLabel.text          = "T: \(String(describing: numDocs))"
            self.networkLabel.text       = "N: \(String(describing: numDocs))"
            self.cpuLabel.text           = "C: \(String(describing: numDocs))"
            self.numSyncedDocsLabel.text = "S: \(String(describing: numDocs))"
        }
    }
    
    @IBAction func clearAllDocsClicked(_ sender: Any) {
        let numDocs = integer(from: numDocsToInsertInput)
        DispatchQueue.main.async() {
            self.timeLabel.text          = "T: \(String(describing: numDocs))"
            self.networkLabel.text       = "N: \(String(describing: numDocs))"
            self.cpuLabel.text           = "C: \(String(describing: numDocs))"
            self.numSyncedDocsLabel.text = "S: \(String(describing: numDocs))"
        }
    }
    
    @IBAction func syncPassClicked(_ sender: Any) {
        let numDocs = integer(from: numDocsToInsertInput)
        DispatchQueue.main.async() {
            self.timeLabel.text          = "T: \(String(describing: numDocs))"
            self.networkLabel.text       = "N: \(String(describing: numDocs))"
            self.cpuLabel.text           = "C: \(String(describing: numDocs))"
            self.numSyncedDocsLabel.text = "S: \(String(describing: numDocs))"
        }
    }
    
    func integer(from textField: UITextField) -> Int {
        guard let text = textField.text, let number = Int(text) else {
            return 0
        }
        return number
    }
}

