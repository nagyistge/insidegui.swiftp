//
//  Document.swift
//  SwiFTP
//
//  Created by Guilherme Rambo on 24/12/14.
//  Copyright (c) 2014 Guilherme Rambo. All rights reserved.
//

import Cocoa

public class FTPDocument: NSDocument, NSTableViewDataSource, NSTableViewDelegate {

    var client:FTPClient?
    var currentURL:NSURL?
    var urlHistory:NSMutableArray?
    var currentHistoryIndex:Int = 0
    @IBOutlet var tableView:NSTableView!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var urlField: NSTextField!
    @IBOutlet weak var historyNavigationControl: NSSegmentedControl!
    var files:NSArray?
    var dateFormatter:NSDateFormatter?
    
    override init() {
        super.init()
        // Add your subclass-specific initialization here.
    }

    override public func windowControllerDidLoadNib(aController: NSWindowController) {
        super.windowControllerDidLoadNib(aController)
        
        historyNavigationControl.setEnabled(false, forSegment: 0)
        historyNavigationControl.setEnabled(false, forSegment: 1)
        progressIndicator.hidden = true
        windowForSheet!.titleVisibility = .Hidden
        tableView.setDelegate(self)
        tableView.setDataSource(self)
        tableView.target = self
        tableView.doubleAction = Selector("doubleClickedTableRow")
    }

    override public class func autosavesInPlace() -> Bool {
        return true
    }

    override public var windowNibName: String? {
        return "FTPDocument"
    }

    override public func dataOfType(typeName: String, error outError: NSErrorPointer) -> NSData? {
        // Insert code here to write your document to data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning nil.
        // You can also choose to override fileWrapperOfType:error:, writeToURL:ofType:error:, or writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
        outError.memory = NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
        return nil
    }

    override public func readFromData(data: NSData, ofType typeName: String, error outError: NSErrorPointer) -> Bool {
        // Insert code here to read your document from the given data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning false.
        // You can also choose to override readFromFileWrapper:ofType:error: or readFromURL:ofType:error: instead.
        // If you override either of these, you should also override -isEntireFileLoaded to return NO if the contents are lazily loaded.
        outError.memory = NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
        return false
    }

    // MARK: Actions
    
    @IBAction func urlFieldAction(sender: AnyObject?) {
        var textField = sender as NSTextField
        
        if let url = NSURL(string: textField.stringValue) {
            navigateTo(url, registerHistory: true)
        } else {
            var alert = NSAlert()
            alert.messageText = "Invalid URL"
            alert.informativeText = "The URL entered is not a valid FTP URL."
            alert.addButtonWithTitle("Ok")
            alert.runModal()
        }
    }
    
    func navigateTo(url: NSURL, registerHistory: Bool) {
        currentURL = url
        urlField.stringValue = url.absoluteString!
        progressIndicator.hidden = false
        progressIndicator.startAnimation(nil)
        
        client = FTPClient(url: url)
        client?.list({ (client) -> () in
            if (client.failed) {
                var alert = NSAlert()
                alert.messageText = "Something went wrong"
                alert.informativeText = client.status
                alert.addButtonWithTitle("Ok")
                alert.runModal()
            } else {
                if (registerHistory) {
                    self.addURLToHistory(url)
                }
                
                if let entries = self.client!.listEntries {
                    self.files = entries.copy() as? NSArray
                    self.tableView.reloadData()
                } else {
                    let alert = NSAlert()
                    alert.messageText = "No files"
                    alert.informativeText = "This path contains no files"
                    alert.beginSheetModalForWindow(self.windowForSheet!, completionHandler: nil)
                }
                
                self.client = nil
            }
            
            self.progressIndicator.stopAnimation(nil)
            self.progressIndicator.hidden = true
        })
    }
    
    // MARK: Table View
    
    public func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        if let count = self.client?.listEntries?.count {
            return count
        } else {
            return 0
        }
    }
    
    public func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var cellID = "filenameCell"
        var cellString = ""

        let entry:NSDictionary = self.files!.objectAtIndex(row) as NSDictionary

        if (tableColumn?.identifier == "size") {
            // size
            cellID = "sizeCell"
            var size = entry.objectForKey(kCFFTPResourceSize) as NSNumber
            if (size.isKindOfClass(NSNumber)) {
                cellString = String.stringForFileSize(size.doubleValue)
            } else {
                cellString = "-"
            }
        } else if (tableColumn?.identifier == "modified") {
            // modified at
            cellID = "modifiedCell"
            var date:NSDate = entry.objectForKey(kCFFTPResourceModDate) as NSDate
            if (date.isKindOfClass(NSDate)) {
                if (dateFormatter == nil) {
                    dateFormatter = NSDateFormatter()
                    dateFormatter!.dateStyle = .ShortStyle
                    dateFormatter!.timeStyle = .ShortStyle
                }

                cellString = dateFormatter!.stringFromDate(date)
            } else {
                cellString = "-"
            }
        } else {
            // filename
            cellID = "filenameCell"
            cellString = (entry.objectForKey(kCFFTPResourceName) as String).convertFromRomanToUTF8()
        }
        
        var cellView: NSTableCellView? = tableView.makeViewWithIdentifier(cellID, owner: tableView) as? NSTableCellView
        
        cellView!.textField!.stringValue = cellString
        
        return cellView
    }
    
    // MARK: State Restoration
    
    public override func encodeRestorableStateWithCoder(coder: NSCoder) {
        super.encodeRestorableStateWithCoder(coder)
        
        coder.encodeObject(currentURL, forKey: "currentURL")

        if (urlHistory?.count > 0) {
            coder.encodeObject(urlHistory, forKey: "urlHistory")
        }
        
        if (currentHistoryIndex > 0) {
            coder.encodeInteger(currentHistoryIndex, forKey: "currentHistoryIndex")
        }
    }
    
    public override func restoreStateWithCoder(coder: NSCoder) {
        super.restoreStateWithCoder(coder)
        
        let savedURL = coder.decodeObjectForKey("currentURL") as? NSURL
        
        urlHistory = coder.decodeObjectForKey("urlHistory") as? NSMutableArray
        currentHistoryIndex = coder.decodeIntegerForKey("currentHistoryIndex")
        if (currentHistoryIndex > 0 && urlHistory?.count > 0) {
            navigateTo(urlHistory!.objectAtIndex(currentHistoryIndex) as NSURL, registerHistory: false)
            historyNavigationControl.setEnabled(true, forSegment: 0)
            if (currentHistoryIndex < (urlHistory!.count-1)) {
                historyNavigationControl.setEnabled(true, forSegment: 1)
            }
        } else {
            if let url = savedURL {
                navigateTo(url, registerHistory: true)
            }
        }
    }
    
    // MARK: Navigation
    
    func addURLToHistory(url: NSURL) {
        if (urlHistory == nil) {
            urlHistory = NSMutableArray()
            urlHistory!.addObject(url)
            currentHistoryIndex=0
        } else {
            currentHistoryIndex++
            urlHistory!.insertObject(url, atIndex: currentHistoryIndex)
        }
        
        if (currentHistoryIndex > 0) {
            self.historyNavigationControl.setEnabled(true, forSegment: 0)
        }
    }
    
    @IBAction func goBackOrForward(sender: AnyObject) {
        if (historyNavigationControl.selectedSegment == 0) {
            goBack()
        } else {
            goForward()
        }
    }
    
    func goBack()
    {
        currentHistoryIndex -= 1
        navigateTo(urlHistory!.objectAtIndex(currentHistoryIndex) as NSURL, registerHistory: false)
        
        self.historyNavigationControl.setEnabled(true, forSegment: 1)
        
        if (currentHistoryIndex == 0) {
            self.historyNavigationControl.setEnabled(false, forSegment: 0)
        }
    }
    
    func goForward()
    {
        currentHistoryIndex += 1
        navigateTo(urlHistory!.objectAtIndex(currentHistoryIndex) as NSURL, registerHistory: false)
        
        self.historyNavigationControl.setEnabled(true, forSegment: 0)
        
        if (currentHistoryIndex == urlHistory!.count-1) {
            self.historyNavigationControl.setEnabled(false, forSegment: 1)
        }
    }
    
    func doubleClickedTableRow() {
        var file = files?.objectAtIndex(tableView.clickedRow) as NSDictionary
        if let folder = file.objectForKey(kCFFTPResourceName) as? String {
            if (folder.rangeOfString(".", options: NSStringCompareOptions.LiteralSearch, range: nil, locale: nil) == nil) {
                let absoluteString = NSString(format: "%@%@", currentURL!.absoluteString!, folder)
                let url = NSURL(string: absoluteString.stringByAppendingString("/"))
                navigateTo(url!, registerHistory: true)
            }
        }
    }
    
}

