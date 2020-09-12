//
//  ViewController.swift
//  HSGLPanoViewer
//
//  Created by Hanson on 2020/9/12.
//  Copyright © 2020 Hanson. All rights reserved.
//

import UIKit
import GLKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    @IBAction func showGLKitPano(_ sender: Any) {
        let vc = GLKitPanoViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func showGLSLPano(_ sender: Any) {
        
    }
    
}

