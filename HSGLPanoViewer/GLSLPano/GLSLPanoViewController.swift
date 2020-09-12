//
//  GLSLPanoViewController.swift
//  HSGLPanoViewer
//
//  Created by Hanson on 2020/9/12.
//  Copyright © 2020 Hanson. All rights reserved.
//

import UIKit

class GLSLPanoViewController: UIViewController {

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.view = GLSLPanoView(frame: view.frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

}
