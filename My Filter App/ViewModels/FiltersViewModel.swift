//
//  FiltersViewModel.swift
//  My Filter App
//
//  Created by Arsal on 09/04/2023.
//

import Foundation
import UIKit
import GPUImage

class FiltersViewModel{
    
private let filterService: FilterService
private var filterCategories: [FilterCategory] = []

init(filterService: FilterService = FilterService()) {
    self.filterService = filterService
    filterCategories   = filterService.getFilterCategories()
}

func fetchFilterCategories(completion: @escaping () -> Void) {
    filterCategories = filterService.getFilterCategories()
    completion()
}

func numberOfSections() -> Int {
    return filterCategories.count
}

func numberOfFiltersInSection(_ section: Int) -> Int {
    return filterCategories[section].filters.count
}

func filterCategoryName(forSection section: Int) -> String {
    return filterCategories[section].name
}

func filterCategory(forSection section: Int) -> FilterCategory {
        return filterCategories[section]
}

    
func filter(forIndexPath indexPath: IndexPath) -> Filter {
    return filterCategories[indexPath.section].filters[indexPath.row]
}
    
}
