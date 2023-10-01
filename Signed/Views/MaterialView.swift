//
//  MaterialView.swift
//  Signed
//
//  Created by Markus Moenig on 30/9/23.
//

import SwiftUI
import Combine

#if os(iOS)
import CoreData
import MobileCoreServices
#endif

struct MaterialView: View {
    
    @Environment(\.managedObjectContext) private var viewContext
    
    let model                               : Model
    var material                            : Material

    init(model: Model, material: Material) {
        self.model = model
        self.material = material
    }
    
    var body: some View {
        
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                RenderView(model: model, mode: .Render3D)
                    .frame(width: geometry.size.width / 2, height: geometry.size.width / 2)
                
                MaterialSettings(model: model, material: material)
                    .padding(.leading, geometry.size.width - 300)
            }
        }
        
        .onAppear() {
            model.materialChanged.send(material)
        }
    }
}
