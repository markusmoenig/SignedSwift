//
//  ModelView.swift
//  Signed
//
//  Created by Markus Moenig on 29/9/23.
//

import SwiftUI
import Combine

#if os(iOS)
import CoreData
import MobileCoreServices
#endif

struct ModelView: View {
    
    @Environment(\.managedObjectContext) private var viewContext
    
    let model                                           : Model

    @ObservedObject var project                         : Project
    
    @State var selectedPoint                            : Point? = nil
    @State var selectedLine                             : Line? = nil
    @State var selectedShape                            : Shape? = nil
    
    init(model: Model, project: Project) {
        self.model = model
        self.project = project
    }
    
    var body: some View {
        
        GeometryReader { geometry in
            
            ZStack(alignment: .bottomLeading) {
                RenderView(model: model, mode: .Points3D)
            }
        }
    }
}
