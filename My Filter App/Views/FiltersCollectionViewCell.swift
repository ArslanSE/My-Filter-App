//
//  FiltersCollectionViewCell.swift
//  My Filter App
//
//  Created by Arsal on 09/04/2023.
//

import UIKit

class FiltersCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var filterImageView: UIImageView!
    @IBOutlet weak var filterNameLabel: UILabel!
       
       override func awakeFromNib() {
           super.awakeFromNib()
           self.contentView.layer.cornerRadius = 10
           self.filterImageView.layer.cornerRadius = 10
           self.filterImageView.layer.masksToBounds = true
           self.contentView.layer.masksToBounds = true
       }
}
