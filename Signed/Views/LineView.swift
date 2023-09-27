//
//  ShapeView.swift
//  Signed
//
//  Created by Markus Moenig on 24/9/23.
//

import SwiftUI
import Combine

#if os(iOS)
import CoreData
import MobileCoreServices
#endif

struct LineView: View {
    
    @Environment(\.managedObjectContext) private var viewContext
    
    let model                               : Model
    var project                             : Project
    let line                                : Line
    
    init(model: Model, project: Project, line: Line) {
        self.model = model
        self.project = project
        self.line = line
        
    }
    
    var body: some View {
        
        VStack(alignment: .leading) {
            Text(line.name!)
                .font(.system(size: 18))
                .onTapGesture(perform: {
                })
         }
    }
    
    /// Save the context
    func save(_ text: String) {
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print(text, nsError)
        }
    }
}
        
