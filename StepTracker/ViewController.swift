//
//  ViewController.swift
//  StepTracker
//
//  Created by Andrew Conrad on 5/31/16.
//  Copyright © 2016 AndrewConrad. All rights reserved.
//

import UIKit
import HealthKit
import PNChart

class ViewController: UIViewController, PNChartDelegate {
    
    var healthStore = HKHealthStore()
    var weeklyStepsArray :[Double]!
    var threeMonthStepsArray :[Double]!
    var sixMonthStepsArray :[Double]!
    
    @IBOutlet   var     historySegmentedControl     :UISegmentedControl!
    
    @IBAction   func     historySegCntChanged(sender: UISegmentedControl) {
        readUserStepsInfo()
    }
    
    
    
    //MARK: - Data Methods

    func dataTypesToRead() -> Set<HKObjectType> {
        let stepsType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierStepCount)!
        return [stepsType]
    }
    
    func requestAuthorization() {
        if HKHealthStore.isHealthDataAvailable() {
            healthStore.requestAuthorizationToShareTypes(nil, readTypes: dataTypesToRead(), completion: { (success, error) in
                if success {
                    dispatch_async(dispatch_get_main_queue(), {
                        print("Sucess")
                    })
                } else {
                    print("Error: \(error)")
                }
            })
        }
    }
    
    func readUserStepsInfo() {
        resetArrays()
        let stepsType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierStepCount)!
        
        let endDate = cleanDate(NSDate())
        var dayCount = 1
        switch historySegmentedControl.selectedSegmentIndex {
        case 0:
            dayCount = -7
        case 1:
            dayCount = -84
        case 2:
            dayCount = -180
        default:
            print("No Segment Selected")
        }

        let startDate = NSCalendar.currentCalendar().dateByAddingUnit(.Day, value: dayCount, toDate: endDate, options: [])
        let limit = abs(dayCount * 500)
        let predicate = HKQuery.predicateForSamplesWithStartDate(startDate, endDate: endDate, options: .None)
        
        let query = HKSampleQuery(sampleType: stepsType, predicate: predicate, limit: limit, sortDescriptors: nil) { (query, results, error) in
            var totalSteps = 0.0
            
            let cleanCurrentDate = self.cleanDate(NSDate())
            for steps in results as! [HKQuantitySample] {
                let currentSteps = steps.quantity.doubleValueForUnit(HKUnit.countUnit())
                totalSteps += currentSteps
                let cleanStartDate = self.cleanDate(steps.startDate)
                
    //SUPER DUPER CONFUSING DATE COMPARISONS
    //I still don't understand. And probably never will.
                switch self.historySegmentedControl.selectedSegmentIndex {
                case 0:
                    
                    for index in 1...7 {
                        let bucketDate = cleanCurrentDate.dateByAddingTimeInterval(-1 * Double(index) * 24 * 60 * 60)
                        if bucketDate == cleanStartDate {
                            self.weeklyStepsArray[index - 1] += currentSteps
                            break
                        }
                    }
                case 1:
                    
                    for index in 0...11 {
                        let weekEndDate = cleanCurrentDate.dateByAddingTimeInterval(-1 * Double(index) * 24 * 60 * 60 * 7)
                        let weekStartDate = cleanCurrentDate.dateByAddingTimeInterval(-1 * Double(index + 1) * 24 * 60 * 60 * 7)
                        if (weekStartDate.compare(cleanStartDate) == .OrderedAscending || weekStartDate.compare(cleanStartDate) == .OrderedSame) &&
                            (cleanStartDate.compare(weekEndDate) == .OrderedAscending || cleanStartDate.compare(weekEndDate) == .OrderedSame) {
                            self.threeMonthStepsArray[index] += currentSteps
                            break
                        }
                    }
                case 2:
                    
                    for index in 0...5 {
                        let monthEndDate = cleanCurrentDate.dateByAddingTimeInterval(-1 * Double(index) * 24 * 60 * 60 * 30)
                        let monthStartDate = cleanCurrentDate.dateByAddingTimeInterval(-1 * Double(index + 1) * 24 * 60 * 60 * 30)
                        if (monthStartDate.compare(cleanStartDate) == .OrderedAscending || monthStartDate.compare(cleanStartDate) == .OrderedSame) && (cleanStartDate.compare(monthEndDate) == .OrderedAscending || cleanStartDate.compare(monthEndDate) == .OrderedSame) {
                            self.sixMonthStepsArray[index] += currentSteps
                            break
                        }
                    }
                default:
                    print("No Segment Selected")
                }
            }
            
            dispatch_async(dispatch_get_main_queue(), {
    //WISHLIST: Add a label that shows this below the bar chart in the VC
                print("Total Steps \(totalSteps)")
        //Old debug prints
//                print("Post: \(self.weeklyStepsArray)")
//                print("Post: \(self.threeMonthStepsArray)")
//                print("Post: \(self.sixMonthStepsArray)")
                self.displayBarChart()
            })
        }
        healthStore.executeQuery(query)
    }
    
//Makes sure arrays are clean. Like the old bar chart remover below
    func resetArrays() {
        weeklyStepsArray = [0,0,0,0,0,0,0]
        threeMonthStepsArray = [0,0,0,0,0,0,0,0,0,0,0,0]
        sixMonthStepsArray = [0,0,0,0,0,0]
    }
    
//This function truncates or rounds the time of an NSDate so they are comperable by date alone
    func cleanDate(date: NSDate) -> NSDate {
        let cal = NSCalendar.currentCalendar()
        let comps = cal.components([.Year, .Month, .Day], fromDate: date)
        let cleanDate = cal.dateFromComponents(comps)!
        return cleanDate
    }
    
    
    
    //MARK: - Drawing Methods
    
    func displayBarChart() {
        
// This for loop removes old bar charts to keep memory usage acceptable
        for view in self.view.subviews {
            if view is PNBarChart {
                view.removeFromSuperview()
                print("Found one to remove")
            } else {
                print("Didn't find chart to remove")
            }
        }

// This is the bar initialization stuff, things that are true for each chart
        let myBarChart = PNBarChart(frame: CGRectMake(10,75,300,250))
        myBarChart.barBackgroundColor = UIColor.clearColor()
        myBarChart.barRadius = 3.0
        myBarChart.isShowNumbers = true
    //WISHLIST STUFF HERE
    //I should change the above later. Instead of having numbers on the bars, have the labels below
    //be the number of steps that this isShowNumbers thing is now
        myBarChart.chartMarginTop = 10.0
        myBarChart.chartMarginBottom = 35.0
        myBarChart.showChartBorder = true
        myBarChart.strokeColor = UIColor.blueColor()

//This switch below determines which bar chart to display based on the SegControl at the top of the VC
        switch historySegmentedControl.selectedSegmentIndex {
        case 0:
            myBarChart.yValues = weeklyStepsArray
            myBarChart.barWidth = 32.0
            myBarChart.xLabels = ["1", "2", "3", "4", "5", "6", "7"]
    //MORE WISHLIST
    //So appearantly it needs xlabels in order to have the bars not on top of each other
    //There is probably a better way though
    //But it only took an hour to figure out......
        case 1:
            myBarChart.yValues = threeMonthStepsArray
            myBarChart.barWidth = 18.0
            myBarChart.xLabels = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"]
        case 2:
            myBarChart.yValues = sixMonthStepsArray
            myBarChart.barWidth = 38.0
            myBarChart.xLabels = ["1", "2", "3", "4", "5", "6"]
        default:
            print("No Segment Selected")
        }
        
//These are the draw orders to the app
        myBarChart.strokeChart()
        myBarChart.delegate = self
        self.view.addSubview(myBarChart)
    }


    
    //MARK: - Life Cycle Methods

    override func viewDidLoad() {
        super.viewDidLoad()
        requestAuthorization()
        resetArrays()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}

