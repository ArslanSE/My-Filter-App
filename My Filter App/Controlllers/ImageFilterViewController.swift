//
//  ImageFilterViewController.swift
//  My Filter App
//
//  Created by Arsal on 09/04/2023.
//

import UIKit

class ImageFilterViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var filtersCollectionView: UICollectionView!
    
    @IBAction func cancelAction(_ sender: Any) {
        // Handle cancel action
        imageView.image = UIImage(named: "DefaultImage")
    }
    
    @IBAction func saveAction(_ sender: Any) {
        //
    }

    private let filtersViewModel = FiltersViewModel()

    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }
    
    /**
            Utility function for setting up view
     */
    func setupView(){
        setupCollectionView()
        setupNavigationBar()
    }
    /**
            Utility function for setting collection view
     */

    func setupCollectionView(){
        // Set up  collection view
        filtersCollectionView.delegate = self
        filtersCollectionView.dataSource = self
        filtersCollectionView.register(HeaderView.self,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                        withReuseIdentifier: "HeaderView")
        
    }
    
    /**
            Utility function for setting navigation bar appearance
     */
    func setupNavigationBar(){
        
        let appearance = UINavigationBarAppearance()
        appearance.backgroundColor = .white
        appearance.titleTextAttributes = [.foregroundColor: UIColor.black]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.black]

        navigationController?.navigationBar.tintColor = .black
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.isUserInteractionEnabled = true
        
        navigationController?.navigationBar.delegate = self
    }
}


extension ImageFilterViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return filtersViewModel.numberOfSections()
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filtersViewModel.numberOfFiltersInSection(section)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FiltersCollectionViewCell", for: indexPath) as? FiltersCollectionViewCell else {
            fatalError("Unable to dequeue FilterCell")
        }
        
        let filter = filtersViewModel.filter(forIndexPath: indexPath) as Filter
        cell.filterNameLabel.text = filter.name
        
        let filteredImage = filter.apply(to: UIImage(named: "DefaultImage")!)
        cell.filterImageView.image = filteredImage
        
        return cell
    }
    

    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        if kind == UICollectionView.elementKindSectionHeader {
            let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "HeaderView", for: indexPath) as! HeaderView
            let category  = filtersViewModel.filterCategory(forSection: indexPath.section)

                if let myLabel = headerView.sectionName {
                    myLabel.text = category.name
                }
                return headerView

        }else {
            return  UICollectionReusableView()
        }
    }
    
}

extension ImageFilterViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 80, height:  110)
    }
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
            return CGSize(width: 50, height: 30)
        }
}

extension ImageFilterViewController: UICollectionViewDelegate{
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let selectedFilter = filtersViewModel.filter(forIndexPath: indexPath)
        
        if let imageToApplyFilter = imageView.image{
            imageView.image    = selectedFilter.apply(to: imageToApplyFilter)
        }
    }
}

extension ImageFilterViewController: UINavigationBarDelegate{
    
    
}
